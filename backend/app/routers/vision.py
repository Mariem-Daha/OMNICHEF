"""
Gemini Vision AI endpoints for Cuisinee
- Ingredient scanner: Identify ingredients from a photo → suggest recipes
- Dish identifier: Identify a cooked dish from a photo → find recipe
- Cooking companion: Live video + audio WebSocket → real-time AI cooking guidance
"""

import asyncio
import base64
import json
import logging
import traceback
import uuid
from datetime import datetime
from typing import Optional, List

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException, Body
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_, func

from google import genai
from google.genai import types

from ..config import get_settings
from ..database import get_db
from ..models.recipe import Recipe
from ..models.user import User
from ..services.auth_service import get_current_user
from ..modules.function_registry import FunctionRegistry

router = APIRouter(prefix="/vision", tags=["Vision AI"])
logger = logging.getLogger(__name__)
settings = get_settings()

# ── Model IDs ──────────────────────────────────────────────────────────────────
VISION_MODEL = "gemini-2.0-flash-exp"          # Used for single-image REST analysis
COMPANION_MODEL_VERTEX = "gemini-live-2.5-flash-native-audio"  # Vertex AI Live model
COMPANION_MODEL_KEY    = "gemini-2.0-flash-live-001"           # Stable Gemini API Live model

# Active companion sessions
companion_sessions: dict[str, "CompanionSession"] = {}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_client() -> genai.Client:
    """Return a Gemini client using available credentials."""
    if settings.vertex_project_id:
        import os
        if settings.google_application_credentials:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_application_credentials
        return genai.Client(
            vertexai=True,
            project=settings.vertex_project_id,
            location=settings.vertex_location,
        )
    if settings.gemini_api_key:
        return genai.Client(api_key=settings.gemini_api_key)
    raise ValueError("No Gemini credentials configured")


def _recipe_to_dict(recipe: Recipe) -> dict:
    """Minimal recipe dict for API response."""
    return {
        "id": str(recipe.id),
        "name": recipe.name,
        "description": recipe.description,
        "image_url": recipe.image_url,
        "cuisine": recipe.cuisine,
        "prep_time": recipe.prep_time,
        "cook_time": recipe.cook_time,
        "servings": recipe.servings,
        "calories": recipe.calories,
        "tags": recipe.tags or [],
        "ingredients": recipe.ingredients or [],
        "difficulty": recipe.difficulty,
        "rating": recipe.rating,
    }


def _strip_json_fence(text: str) -> str:
    """Strip markdown code fences from Gemini's JSON response."""
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        lines = lines[1:]  # remove opening fence
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines)
    return text.strip()


# ── Request/Response schemas ──────────────────────────────────────────────────

class ScanRequest(BaseModel):
    image_b64: str           # Base64-encoded JPEG/PNG
    mime_type: str = "image/jpeg"


class IngredientScanResponse(BaseModel):
    ingredients: List[str]
    quantities: List[str]
    health_notes: List[str]
    recipes: list


class DishScanResponse(BaseModel):
    dish_name: str
    cuisine: str
    confidence: float
    description: str
    health_tags: List[str]
    recipes: list


# ══════════════════════════════════════════════════════════════════════════════
# 1. INGREDIENT SCANNER  (POST /api/vision/scan-ingredients)
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/scan-ingredients", response_model=IngredientScanResponse)
async def scan_ingredients(
    body: ScanRequest,
    db: Session = Depends(get_db),
):
    """
    Analyse a photo of a fridge / pantry / table.
    Returns identified ingredients + matching recipes from the local DB.
    """
    try:
        client = _get_client()
        image_bytes = base64.b64decode(body.image_b64)

        prompt = """You are an expert culinary AI. Look at this image carefully and identify ALL food ingredients visible.

Return ONLY valid JSON — no markdown, no explanation:
{
  "ingredients": ["ingredient1", "ingredient2", ...],
  "quantities": ["~200g", "3 pieces", ...],
  "health_notes": ["note about any ingredient if relevant", ...]
}

Be specific: e.g. "red bell pepper" not "pepper". Include spices, oils, herbs if visible."""

        response = client.models.generate_content(
            model=VISION_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=body.mime_type),
                prompt,
            ],
        )

        raw = _strip_json_fence(response.text or "{}")
        data = json.loads(raw)
        ingredients: List[str] = data.get("ingredients", [])
        quantities: List[str] = data.get("quantities", [])
        health_notes: List[str] = data.get("health_notes", [])

        # Search DB for recipes that match any detected ingredient
        recipes = []
        if ingredients:
            conditions = [
                Recipe.name.ilike(f"%{ing}%")
                for ing in ingredients[:6]   # cap to avoid huge OR queries
            ]
            db_recipes = (
                db.query(Recipe)
                .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
                .filter(or_(*conditions))
                .order_by(func.random())
                .limit(8)
                .all()
            )
            recipes = [_recipe_to_dict(r) for r in db_recipes]

        return IngredientScanResponse(
            ingredients=ingredients,
            quantities=quantities,
            health_notes=health_notes,
            recipes=recipes,
        )

    except json.JSONDecodeError as e:
        logger.error(f"❌ JSON parse error from Gemini: {e}  raw={response.text[:200]}")
        raise HTTPException(status_code=502, detail="AI returned invalid response. Please try again.")
    except Exception as e:
        logger.error(f"❌ Ingredient scan error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════════════════════════
# 2. DISH IDENTIFIER  (POST /api/vision/identify-dish)
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/identify-dish", response_model=DishScanResponse)
async def identify_dish(
    body: ScanRequest,
    db: Session = Depends(get_db),
):
    """
    Identify a cooked dish from a photo and return the closest recipe from the DB.
    """
    try:
        client = _get_client()
        image_bytes = base64.b64decode(body.image_b64)

        prompt = """You are an expert in Mauritanian, West-African, and MENA cuisine.
Look at this image of a prepared dish and identify it.

Return ONLY valid JSON — no markdown, no explanation:
{
  "dish_name": "name of the dish",
  "cuisine": "e.g. Mauritanian, Moroccan, Lebanese …",
  "confidence": 0.92,
  "description": "1-sentence description",
  "health_tags": ["e.g. High Protein", "Low Carb", "Gluten-Free", ...]
}

If the dish is unknown or unclear, set dish_name to "Unknown dish" and confidence to 0.3."""

        response = client.models.generate_content(
            model=VISION_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=body.mime_type),
                prompt,
            ],
        )

        raw = _strip_json_fence(response.text or "{}")
        data = json.loads(raw)
        dish_name: str = data.get("dish_name", "Unknown dish")
        cuisine: str = data.get("cuisine", "")
        confidence: float = float(data.get("confidence", 0.5))
        description: str = data.get("description", "")
        health_tags: List[str] = data.get("health_tags", [])

        # Search DB for the identified dish
        search_terms = dish_name.replace(",", " ").split()[:3]
        conditions = [Recipe.name.ilike(f"%{term}%") for term in search_terms if len(term) > 2]

        recipes = []
        if conditions:
            db_recipes = (
                db.query(Recipe)
                .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
                .filter(or_(*conditions))
                .limit(6)
                .all()
            )
            recipes = [_recipe_to_dict(r) for r in db_recipes]

        return DishScanResponse(
            dish_name=dish_name,
            cuisine=cuisine,
            confidence=confidence,
            description=description,
            health_tags=health_tags,
            recipes=recipes,
        )

    except json.JSONDecodeError as e:
        logger.error(f"❌ JSON parse error from Gemini: {e}")
        raise HTTPException(status_code=502, detail="AI returned invalid response. Please try again.")
    except Exception as e:
        logger.error(f"❌ Dish identification error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════════════════════════
# 3. COOKING COMPANION  (WS /api/vision/ws/companion)
#    — Real-time video + audio → Gemini Live multimodal → Audio/text guidance
# ══════════════════════════════════════════════════════════════════════════════

COMPANION_SYSTEM_INSTRUCTION = """
You are Cuisinee — a warm, expert AI sous chef who is WITH the user in their kitchen.
You can SEE through their live camera AND hear their voice in real time.

═══ LANGUAGE RULE (STRICT) ═══
Always respond in the EXACT language the user just spoke.
  - Arabic → fluent natural Arabic
  - Darija (Moroccan/Mauritanian dialect) → respond in Darija
  - French → elegant conversational French
  - English → warm, friendly English
Never mix languages.

═══ WHAT YOU CAN DO ═══
1. SEE: You receive live camera frames.  Reference them directly:
   "I can see the onions are starting to caramelise — perfect timing!"
   "That looks like it's boiling a bit too hard — turn it down a notch."

2. IDENTIFY: If the camera shows a dish or ingredients, identify them proactively:
   "That looks like Thieboudienne — a classic Mauritanian fish and rice dish!"
   "I can see tomatoes, onions, and garlic — perfect base for a sauce."
   Then immediately call find_recipe() to pull up the full recipe.

3. GUIDE: Give real-time step guidance, corrections, and tips while cooking.

4. SEARCH RECIPES: Use the tools below whenever any dish or ingredient is mentioned.

═══ TOOL CALLING RULE (CRITICAL) ═══
When you need to call a tool:
  1. Call the tool IMMEDIATELY — do NOT say anything before calling it.
  2. Wait silently for the result.
  3. Speak ONCE after you have the result — never before.
Violating this causes you to repeat yourself.

═══ TOOLS ═══
1. find_recipe(query)              → Search by dish name, ingredient, or description.
2. get_popular_recipes()           → Use for "surprise me" or open-ended requests.
3. get_recipes_by_category(cat)    → Use for cuisine-type questions.
4. get_recipe_details(recipe_id)   → Full recipe details when user wants to cook it.
5. set_timer(minutes)              → ALWAYS call when a cooking duration is mentioned.

═══ VOICE RESPONSE STYLE ═══
- Maximum 2-3 sentences per response — unless the user explicitly asked for a full recipe.
- React to what you SEE: reference the camera, cooking progress, ingredients visible.
- Short pauses between sentences feel natural — never rush.
- Celebrate small wins: "That looks gorgeous!", "Great technique!"
- Never lecture; one actionable tip at a time.
- End with a gentle follow-up question to keep the conversation flowing.

═══ HEALTH-FIRST COOKING ═══
The user profile below may include health conditions common in Mauritania:
diabetes, hypertension, anemia, high cholesterol.
- Automatically offer 1-2 healthy substitutions relevant to their conditions.
- Alert immediately if you see an allergen ingredient on camera.
- Diabetes: suggest brown rice, less oil, cinnamon.
- Hypertension: halve salt, use lemon/herbs.
- Anemia: suggest spinach, lentils, sesame.
- Heart-Healthy: olive oil, grilled not fried, garlic/turmeric.

═══ CULTURAL AWARENESS ═══
- All recommendations are Halal by default.
- Know Mauritanian staples: Thieboudienne, Mafé, Ceebu Jen, Harees, Shakshouka.
- Greet in the user's language: Marhaba! / Salam! / Bonjour! / Hello!
"""

SEND_SAMPLE_RATE = 16000
RECEIVE_SAMPLE_RATE = 24000


class CompanionSession:
    """Manages a single Gemini Live multimodal (video + audio) companion session."""

    def __init__(self, websocket: WebSocket, user_context: dict, db=None):
        self.websocket = websocket
        self.user_context = user_context  # {health_filters, allergies, disliked_ingredients, ...}
        self.db = db
        self.session_id = f"vis_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
        self.client: Optional[genai.Client] = None
        self.gemini_session = None
        self._use_vertex = False
        self.is_active = False
        self.start_time = datetime.now()
        # Function registry (if db available)
        self.functions = FunctionRegistry.get_callable_functions(db) if db else {}

    def _build_system_instruction(self) -> str:
        """Append user's health context to base system instruction."""
        ctx = self.user_context
        extra_parts = []

        if ctx.get("health_filters"):
            filters = ", ".join(ctx["health_filters"])
            extra_parts.append(f"USER HEALTH CONDITIONS: {filters} — always keep these in mind when giving advice.")
        if ctx.get("allergies"):
            allergies = ", ".join(ctx["allergies"])
            extra_parts.append(f"USER ALLERGIES: {allergies} — alert the user immediately if you see these in their cooking.")
        if ctx.get("disliked_ingredients"):
            dislikes = ", ".join(ctx["disliked_ingredients"])
            extra_parts.append(f"USER DISLIKES: {dislikes} — note if you see these being used.")
        if ctx.get("cooking_skill"):
            extra_parts.append(f"USER COOKING SKILL: {ctx['cooking_skill']} — calibrate your advice accordingly.")

        if extra_parts:
            return COMPANION_SYSTEM_INSTRUCTION + "\n\n═══ USER PROFILE ═══\n" + "\n".join(extra_parts)
        return COMPANION_SYSTEM_INSTRUCTION

    async def initialize(self) -> bool:
        """Initialize Gemini client."""
        try:
            if settings.vertex_project_id:
                import os
                if settings.google_application_credentials:
                    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_application_credentials
                self.client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                )
                self._use_vertex = True
            elif settings.gemini_api_key:
                self.client = genai.Client(
                    api_key=settings.gemini_api_key,
                    http_options={"api_version": "v1alpha"},
                )
                self._use_vertex = False
            else:
                logger.error("❌ No Gemini credentials for companion session")
                return False
            return True
        except Exception as e:
            logger.error(f"❌ Companion init error: {e}")
            return False

    async def run(self):
        """Run the companion session: relay video frames + audio to Gemini Live."""
        self.is_active = True
        model = COMPANION_MODEL_VERTEX if self._use_vertex else COMPANION_MODEL_KEY
        system_instruction = self._build_system_instruction()

        # Build tools schema if db is available
        tools_schema = FunctionRegistry.get_tools_schema() if self.db else []

        config = types.LiveConnectConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Aoede")
                )
            ),
            system_instruction=types.Content(
                parts=[types.Part(text=system_instruction)],
                role="user",
            ),
            tools=tools_schema if tools_schema else None,
        )

        logger.info(f"🎥 Starting companion session {self.session_id} model={model}")

        try:
            async with self.client.aio.live.connect(model=model, config=config) as session:
                self.gemini_session = session

                # Confirm connection to Flutter client
                await self.websocket.send_json({
                    "type": "connected",
                    "session_id": self.session_id,
                })

                # Greeting
                await session.send(
                    input="Greet the user briefly and let them know you can see their camera feed and will help them cook. Keep it to 2 sentences.",
                    end_of_turn=True,
                )

                # Run send and receive concurrently
                send_task = asyncio.create_task(self._send_loop(session))
                recv_task = asyncio.create_task(self._recv_loop(session))

                done, pending = await asyncio.wait(
                    [send_task, recv_task],
                    return_when=asyncio.FIRST_COMPLETED,
                )
                for t in pending:
                    t.cancel()
                    try:
                        await t
                    except asyncio.CancelledError:
                        pass

        except Exception as e:
            logger.error(f"❌ Companion session error: {e}")
            traceback.print_exc()
            try:
                await self.websocket.send_json({"type": "error", "error": str(e)})
            except Exception:
                pass
        finally:
            self.is_active = False
            companion_sessions.pop(self.session_id, None)

    async def _send_loop(self, session):
        """Receive frames/audio from Flutter client and forward to Gemini."""
        try:
            while self.is_active:
                message = await asyncio.wait_for(
                    self.websocket.receive(), timeout=120.0
                )

                if "text" in message:
                    data = json.loads(message["text"])
                    msg_type = data.get("type")

                    if msg_type == "video_frame":
                        # Video frame from camera (base64 JPEG)
                        frame_b64 = data.get("data", "")
                        if frame_b64:
                            frame_bytes = base64.b64decode(frame_b64)
                            await session.send(
                                input=types.LiveClientRealtimeInput(
                                    media_chunks=[
                                        types.Blob(data=frame_bytes, mime_type="image/jpeg")
                                    ]
                                )
                            )

                    elif msg_type == "audio":
                        # PCM 16kHz audio
                        audio_b64 = data.get("data", "")
                        if audio_b64:
                            audio_bytes = base64.b64decode(audio_b64)
                            await session.send(
                                input=types.LiveClientRealtimeInput(
                                    media_chunks=[
                                        types.Blob(
                                            data=audio_bytes,
                                            mime_type=f"audio/pcm;rate={SEND_SAMPLE_RATE}",
                                        )
                                    ]
                                )
                            )

                    elif msg_type == "audio_video":
                        # Combined audio + video frame
                        audio_b64 = data.get("audio", "")
                        frame_b64 = data.get("video", "")
                        chunks = []
                        if audio_b64:
                            chunks.append(
                                types.Blob(
                                    data=base64.b64decode(audio_b64),
                                    mime_type=f"audio/pcm;rate={SEND_SAMPLE_RATE}",
                                )
                            )
                        if frame_b64:
                            chunks.append(
                                types.Blob(
                                    data=base64.b64decode(frame_b64),
                                    mime_type="image/jpeg",
                                )
                            )
                        if chunks:
                            await session.send(
                                input=types.LiveClientRealtimeInput(media_chunks=chunks)
                            )

                    elif msg_type == "text":
                        # Plain text message (e.g. user typed a question)
                        text = data.get("text", "")
                        if text:
                            await session.send(input=text, end_of_turn=True)

                    elif msg_type == "interrupt":
                        # User started speaking — acknowledge; Gemini's own VAD will handle it
                        try:
                            await session.send(
                                input=types.LiveClientContent(turn_complete=True)
                            )
                        except Exception:
                            pass
                        await self.websocket.send_json({"type": "interrupt_ack"})

                    elif msg_type == "end_of_turn":
                        await session.send(input=" ", end_of_turn=True)

                    elif msg_type == "disconnect":
                        self.is_active = False
                        break

                elif "bytes" in message:
                    # Raw binary audio data
                    await session.send(
                        input=types.LiveClientRealtimeInput(
                            media_chunks=[
                                types.Blob(
                                    data=message["bytes"],
                                    mime_type=f"audio/pcm;rate={SEND_SAMPLE_RATE}",
                                )
                            ]
                        )
                    )

        except WebSocketDisconnect:
            self.is_active = False
        except asyncio.TimeoutError:
            self.is_active = False
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"❌ Companion send error: {e}")
            self.is_active = False

    async def _recv_loop(self, session):
        """Receive AI responses from Gemini and send to Flutter client."""
        try:
            while self.is_active:
                try:
                    async for response in session.receive():
                        if not self.is_active:
                            break

                        # Audio output
                        if hasattr(response, "data") and response.data:
                            try:
                                audio_data = response.data
                                if isinstance(audio_data, bytes):
                                    sample = audio_data[:20] if len(audio_data) >= 20 else audio_data
                                    if all(43 <= b <= 122 for b in sample) and len(audio_data) > 4:
                                        pad = len(audio_data) % 4
                                        if pad:
                                            audio_data += b"=" * (4 - pad)
                                        audio_bytes = base64.b64decode(audio_data)
                                    else:
                                        audio_bytes = audio_data
                                elif isinstance(audio_data, str):
                                    pad = len(audio_data) % 4
                                    if pad:
                                        audio_data += "=" * (4 - pad)
                                    audio_bytes = base64.b64decode(audio_data)
                                else:
                                    continue

                                # Strip WAV header if present
                                if len(audio_bytes) > 44 and audio_bytes.startswith(b"RIFF"):
                                    audio_bytes = audio_bytes[44:]

                                await self.websocket.send_json({
                                    "type": "audio",
                                    "data": base64.b64encode(audio_bytes).decode("utf-8"),
                                    "sample_rate": RECEIVE_SAMPLE_RATE,
                                    "mime_type": "audio/pcm",
                                })
                            except Exception as audio_err:
                                logger.error(f"❌ Audio relay error: {audio_err}")

                        # Text output
                        if hasattr(response, "text") and response.text:
                            await self.websocket.send_json({
                                "type": "transcript",
                                "text": response.text,
                            })

                        # ── Tool / function calls ─────────────────────────────────
                        _tc = getattr(response, 'tool_call', None)
                        _fc_list = []
                        if _tc:
                            _raw = getattr(_tc, 'function_calls', None)
                            if _raw:
                                _fc_list = list(_raw)
                        if not _fc_list:
                            _fb = getattr(response, 'tool_calls', None)
                            if _fb:
                                _fc_list = list(_fb)

                        for fc in _fc_list:
                            fn_name = fc.name
                            fn_args = dict(getattr(fc, 'args', {}) or {})
                            call_id = str(getattr(fc, 'id', '') or '')
                            try:
                                if fn_name in self.functions:
                                    result = await self.functions[fn_name](**fn_args)
                                    safe_result = json.loads(json.dumps(result, default=str))
                                    fr_kwargs = {
                                        "name": fn_name,
                                        "response": {"output": safe_result},
                                    }
                                    if call_id:
                                        fr_kwargs["id"] = call_id
                                    await self.gemini_session.send(
                                        input=types.LiveClientToolResponse(
                                            function_responses=[types.FunctionResponse(**fr_kwargs)]
                                        )
                                    )
                                    # Notify Flutter client so UI can show recipe card, timer, etc.
                                    await self.websocket.send_json({
                                        "type": "function_executed",
                                        "function": fn_name,
                                        "args": fn_args,
                                        "result": safe_result,
                                    })
                                    logger.info(f"✅ Function executed: {fn_name}")
                            except Exception as fn_err:
                                logger.error(f"❌ Function {fn_name} error: {fn_err}")

                        # Drop audio that co-arrives with a tool call (prevents double-speech)
                        if _fc_list and hasattr(response, 'data') and response.data:
                            pass  # skip

                        # Turn complete
                        if hasattr(response, "server_content") and response.server_content:
                            sc = response.server_content
                            if getattr(sc, "turn_complete", False):
                                await self.websocket.send_json({"type": "turn_complete"})

                except RuntimeError as rte:
                    if "disconnect" in str(rte).lower():
                        break
                    await asyncio.sleep(0.1)

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"❌ Companion recv error: {e}")
            traceback.print_exc()
            self.is_active = False


@router.websocket("/ws/companion")
async def companion_websocket(websocket: WebSocket, db: Session = Depends(get_db)):
    """
    WebSocket endpoint for the AI Cooking Companion.
    Accepts messages:
      - {type: "user_context", health_filters: [...], allergies: [...], ...}  ← FIRST message
      - {type: "video_frame", data: "<base64-JPEG>"}
      - {type: "audio", data: "<base64-PCM-16kHz>"}
      - {type: "audio_video", audio: "<b64-PCM>", video: "<b64-JPEG>"}
      - {type: "text", text: "..."}
      - {type: "disconnect"}
    """
    await websocket.accept()
    logger.info(f"🎥 Cooking companion WebSocket connected")

    # Wait for the first message to get user context
    user_context: dict = {}
    try:
        first_msg = await asyncio.wait_for(websocket.receive(), timeout=10.0)
        if "text" in first_msg:
            data = json.loads(first_msg["text"])
            if data.get("type") == "user_context":
                user_context = data
                logger.info(f"👤 Companion user context received: {list(user_context.keys())}")
    except asyncio.TimeoutError:
        logger.warning("⚠️ No user context received — using defaults")
    except Exception as e:
        logger.warning(f"⚠️ Could not parse user context: {e}")

    if len(companion_sessions) >= 20:
        await websocket.send_json({"type": "error", "error": "Server at capacity. Please try again."})
        await websocket.close(code=1008)
        return

    session = CompanionSession(websocket, user_context, db=db)
    companion_sessions[session.session_id] = session

    if not await session.initialize():
        await websocket.send_json({"type": "error", "error": "Failed to initialize AI companion"})
        await websocket.close(code=1008)
        return

    try:
        await session.run()
    except WebSocketDisconnect:
        logger.info("👋 Cooking companion disconnected")
    except Exception as e:
        logger.error(f"❌ Companion WebSocket error: {e}")
    finally:
        companion_sessions.pop(session.session_id, None)


@router.get("/status")
async def vision_status():
    """Vision AI service status."""
    return {
        "status": "ready",
        "model": VISION_MODEL,
        "features": {
            "ingredient_scan": True,
            "dish_identification": True,
            "cooking_companion": True,
        },
        "active_companion_sessions": len(companion_sessions),
    }
