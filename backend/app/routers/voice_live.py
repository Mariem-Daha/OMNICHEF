"""
Gemini Live API WebSocket Handler for Cuisinee
Real-time bidirectional audio streaming with function calling
Based on proven ChefCode implementation
"""

import os
import asyncio
import base64
import json
import logging
import uuid
import traceback
from datetime import datetime
from typing import Dict, Any, Optional, List
import time

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
import websockets

# Import Google GenAI SDK (v1.0+)
from google import genai
from google.genai import types

# Import local modules
from ..config import get_settings
from ..database import get_db
from ..modules.audio_utils import AudioUtils
from ..modules.vad_handler import VADHandler, SilenceDetector
from ..modules.function_registry import FunctionRegistry

# Initialize router
router = APIRouter(prefix="/voice", tags=["voice"])
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)
settings = get_settings()

# Audio configuration constants
SEND_SAMPLE_RATE = 16000   # Client sends 16kHz
RECEIVE_SAMPLE_RATE = 24000  # Gemini outputs 24kHz

# Gemini Live model on Vertex AI (stable ID as of 2026-02-21)
GEMINI_LIVE_MODEL = 'gemini-live-2.5-flash-native-audio'
# Fallback for Gemini API key (no Vertex)
GEMINI_LIVE_MODEL_FALLBACK = 'models/gemini-2.0-flash-exp'

# Active sessions tracking
active_sessions: Dict[str, "GeminiLiveSession"] = {}

# System instruction for the voice assistant
SYSTEM_INSTRUCTION = """You are Cuisinee — a warm, witty, and deeply knowledgeable AI chef assistant
specializing in Mauritanian, West African, and broader MENA cuisine. You sound exactly
like a real, enthusiastic human chef friend — never robotic, never stiff.

═══ LANGUAGE RULE (STRICT) ═══
Always respond in the EXACT language the user just spoke. Do not mix languages.
  - Arabic → fluent natural Arabic
  - Darija (Moroccan/Mauritanian dialect) → respond in Darija
  - French → elegant conversational French
  - English → warm, friendly English

═══ PERSONALITY ═══
- Speak naturally, like a conversation — not a manual.
- Use short sentences. Pause naturally. React to what was just said.
- Express enthusiasm for food: "Oh that's a classic!", "Great choice!"
- If interrupted, stop immediately and listen — never keep talking.
- Acknowledge interruptions gracefully: "Sure, go ahead!"

═══ TOOL CALLING RULE (CRITICAL) ═══
When you need to call a tool:
  1. Call the tool IMMEDIATELY — do NOT say anything before calling it.
  2. Wait silently for the result.
  3. Speak ONCE after you have the result — never before.
Violating this causes you to repeat yourself. Silence before the call, speech after.

═══ TOOLS — USE THEM PROACTIVELY ═══
1. find_recipe(query)      → Search recipes by name, ingredient, or mood.
   • Always call this when someone asks about any dish or ingredient.
   • After the tool returns, narrate the top result naturally.
   • The UI will show a visual card automatically — just speak the highlights.

2. get_popular_recipes()   → Use when user says "surprise me", "what's good today",
   "recommend something", or any open-ended recipe question.

3. get_recipes_by_category(category) → Use for cuisine-type questions:
   "show me Mauritanian dishes", "something Moroccan", "MENA recipes"

4. get_recipe_details(recipe_id) → Use when user asks "tell me more about that",
   "what are the ingredients?", or "how do I make it?"

5. set_timer(minutes)      → Immediately call when ANY duration is mentioned.
   "cook for 20 minutes" → call set_timer(20).
   After setting, say: "Timer set! I'll let you know when it's done."

═══ VOICE RESPONSE RULES ═══
- Maximum 2-3 sentences per turn unless the user asked for a full recipe.
- Never read long ingredient lists aloud — say "I've shown you the full list on screen."
- When showing recipes visually, say "I've pulled that up on your screen!" and summarize.
- For timers: confirm duration and say something encouraging.
- End with a light follow-up question to keep the conversation flowing.

═══ CULTURAL AWARENESS ═══
- All recipes respect Halal requirements by default.
- Understand Mauritanian staples: Thieboudienne, Mafé, Ceebu Jen, Harees, Shakshouka.
- Know regional ingredient alternatives (e.g., substitute pork with beef/lamb).
- Greet with context: "Marhaba!", "Salam!", "Bonjour!", "Hello there!" based on language.

═══ EXAMPLES OF GREAT RESPONSES ═══
User: "What can I make with carrots?"
You: "Oh carrots are so versatile! I found a few great options — I've shown them on your screen.
My top pick is a slow-cooked Carrot Tagine — rich, warm, and perfect for tonight. Want me to walk you through it?"

User: "Set a timer for 15 minutes"
You: "Done! Timer running for 15 minutes. I'll keep an eye on it for you!"

User: "Show me Mauritanian recipes"
You: "Great taste! I've pulled up some Mauritanian classics for you. The Thieboudienne is calling your name — shall I show you how to make it?"
"""  


class GeminiLiveSession:
    """
    Manages a single Gemini Live API session for a WebSocket client
    Handles bidirectional audio streaming and function calling
    Production-ready implementation with robust error handling
    """

    def __init__(self, websocket: WebSocket, db: Session):
        self.websocket = websocket
        self.db = db
        self.session_id = f"live_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
        self.client: Optional[genai.Client] = None
        self.gemini_session = None
        self._use_vertex: bool = False  # set during initialize()

        # Audio processing
        self.audio_utils = AudioUtils()
        self.vad = VADHandler()
        self.silence_detector = SilenceDetector()

        # Function registry bound to this DB session
        self.functions = FunctionRegistry.get_callable_functions(db)

        # State tracking
        self.is_active = False
        self.audio_buffer: List[bytes] = []
        self.last_speech_time = None

        # Barge-in / interruption state
        # When True, audio chunks from Gemini are dropped so the client stops hearing AI speech
        self._interrupted = False

        # Server-side VAD for reliable end-of-turn detection
        self._user_was_speaking = False
        self._post_speech_silence_frames = 0
        self._EOT_SILENCE_FRAMES = 6    # 6 chunks × ~128ms ≈ 750ms post-speech silence
        self._last_speech_time: float = 0.0  # wall-clock of last speech-active chunk

        # Performance tracking
        self.start_time = time.time()
        self.messages_sent = 0
        self.messages_received = 0
        self.functions_executed = 0
        self.errors = 0

        logger.info(f"✨ Created session: {self.session_id}")

    async def initialize(self):
        """Initialize the Gemini Live session — prefers Vertex AI, falls back to API key."""
        try:
            if settings.vertex_project_id:
                # ── Vertex AI path (recommended: supports gemini-live-2.5-flash) ──
                import os
                if settings.google_application_credentials:
                    # Must be set as OS env var for google-auth ADC to pick it up
                    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = settings.google_application_credentials
                    logger.info(f"🔑 Using service account: {settings.google_application_credentials}")
                self.client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                )
                self._use_vertex = True
                logger.info(f"✅ Vertex AI client initialized (project={settings.vertex_project_id}, location={settings.vertex_location})")
            elif settings.gemini_api_key:
                # ── Gemini API key fallback ──
                self.client = genai.Client(
                    api_key=settings.gemini_api_key,
                    http_options={'api_version': 'v1alpha'}
                )
                self._use_vertex = False
                logger.info(f"✅ Gemini API key client initialized")
            else:
                logger.error("❌ Neither VERTEX_PROJECT_ID nor GEMINI_API_KEY is set")
                await self.websocket.close(code=1008, reason="No AI credentials configured")
                return False

            logger.info(f"✅ Client ready for session: {self.session_id}")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to initialize client: {e}")
            traceback.print_exc()
            return False

    async def start(self):
        """Start the bidirectional streaming session with reconnection support"""
        self.is_active = True
        max_reconnect_attempts = 3
        reconnect_delay = 1.0

        for attempt in range(max_reconnect_attempts):
            try:
                # Get tools schema BEFORE creating config
                tools_schema = FunctionRegistry.get_tools_schema()

                # Live API configuration
                config = types.LiveConnectConfig(
                    response_modalities=["AUDIO"],
                    speech_config=types.SpeechConfig(
                        voice_config=types.VoiceConfig(
                            prebuilt_voice_config=types.PrebuiltVoiceConfig(
                                voice_name="Puck"
                            )
                        )
                    ),
                    system_instruction=types.Content(
                        parts=[types.Part(text=SYSTEM_INSTRUCTION)],
                        role="user",
                    ),
                    tools=tools_schema,
                )

                model = GEMINI_LIVE_MODEL if self._use_vertex else GEMINI_LIVE_MODEL_FALLBACK
                logger.info(f"🔌 Connecting to Gemini Live API (attempt {attempt + 1}/{max_reconnect_attempts}) model={model}")
                tool_names = [fd.name for fd in tools_schema[0].function_declarations]
                logger.info(f"📦 Registered {len(tool_names)} tools: {tool_names}")

                # Connect to Gemini Live
                async with self.client.aio.live.connect(
                    model=model,
                    config=config
                ) as session:
                    self.gemini_session = session
                    logger.info(f"✅ Connected to Gemini Live API: {self.session_id}")

                    # Create concurrent tasks for bidirectional communication
                    client_task = asyncio.create_task(
                        self.handle_client_audio(),
                        name="client_audio"
                    )
                    gemini_task = asyncio.create_task(
                        self.handle_gemini_responses(),
                        name="gemini_responses"
                    )

                    # Wait for either task to complete
                    done, pending = await asyncio.wait(
                        [client_task, gemini_task],
                        return_when=asyncio.FIRST_COMPLETED
                    )

                    # Cancel remaining tasks
                    for task in pending:
                        task.cancel()
                        try:
                            await task
                        except asyncio.CancelledError:
                            pass

                    # Session ended normally
                    logger.info(f"✅ Session ended gracefully: {self.session_id}")
                    break

            except websockets.exceptions.InvalidStatus as e:
                self.errors += 1
                logger.error(f"❌ Gemini API connection failed (attempt {attempt + 1}): {e}")

                if attempt < max_reconnect_attempts - 1:
                    logger.info(f"⏳ Retrying in {reconnect_delay}s...")
                    await asyncio.sleep(reconnect_delay)
                    reconnect_delay *= 2  # Exponential backoff
                else:
                    await self.websocket.send_json({
                        "type": "error",
                        "error": f"Failed to connect to Gemini API after {max_reconnect_attempts} attempts"
                    })
                    break

            except Exception as e:
                self.errors += 1
                logger.error(f"❌ Session error: {e}")
                traceback.print_exc()
                break

        self.is_active = False

        # Clean up
        if self.session_id in active_sessions:
            del active_sessions[self.session_id]

        # Log session stats
        duration = time.time() - self.start_time
        logger.info(f"📊 Session stats: {self.session_id}")
        logger.info(f"   Duration: {duration:.1f}s")
        logger.info(f"   Messages sent: {self.messages_sent}")
        logger.info(f"   Messages received: {self.messages_received}")
        logger.info(f"   Functions executed: {self.functions_executed}")
        logger.info(f"   Errors: {self.errors}")

    async def handle_client_audio(self):
        """
        Receive audio/control messages from client WebSocket
        Send to Gemini Live API with VAD and silence detection
        """
        try:
            # Send connection confirmation to Flutter client
            await self.websocket.send_json({
                "type": "connected",
                "session_id": self.session_id
            })
            logger.info(f"📤 Sent connection confirmation: {self.session_id}")

            # Trigger the AI to greet the user immediately so they hear something right away
            await self.gemini_session.send(
                input="Greet the user warmly and briefly (1-2 sentences). Tell them they can ask about recipes or set cooking timers. Use the same language as they will likely speak.",
                end_of_turn=True
            )
            logger.info("👋 Sent greeting prompt to Gemini")

            while self.is_active:
                try:
                    # Receive message from client
                    message = await asyncio.wait_for(
                        self.websocket.receive(),
                        timeout=300.0  # 5 minute timeout
                    )

                    if "text" in message:
                        data = json.loads(message["text"])
                        msg_type = data.get("type")

                        if msg_type == "audio":
                            # Audio chunk from client
                            audio_b64 = data.get("data")
                            if not audio_b64:
                                continue

                            # Barge-in: first audio chunk after interrupt clears the flag
                            if self._interrupted:
                                self._interrupted = False
                                logger.info("🎤 Barge-in resolved — new user speech incoming")

                            # Decode audio
                            audio_bytes = base64.b64decode(audio_b64)
                            self.messages_received += 1

                            # VAD — energy only (ZCR threshold is unreliable across mic models)
                            is_speech, vad_metrics = self.vad.process_frame(audio_bytes)

                            # Always send audio to Gemini with correct MIME type
                            await self.gemini_session.send(
                                input={
                                    "data": audio_bytes,
                                    "mime_type": f"audio/pcm;rate={SEND_SAMPLE_RATE}"
                                },
                                end_of_turn=False
                            )
                            self.messages_sent += 1

                            # ── Hybrid EOT: frame-count + wall-clock ──
                            # Triggers end_of_turn when:
                            #  A) N silent chunks in a row after speech, OR
                            #  B) >2s wall-clock without any speech chunk
                            now = time.time()
                            if is_speech:
                                self._user_was_speaking = True
                                self._post_speech_silence_frames = 0
                                self._last_speech_time = now
                            elif self._user_was_speaking:
                                self._post_speech_silence_frames += 1
                                wall_silence = now - self._last_speech_time
                                if (
                                    self._post_speech_silence_frames >= self._EOT_SILENCE_FRAMES
                                    or wall_silence > 2.0
                                ):
                                    logger.info(f"🔇 EOT triggered (frames={self._post_speech_silence_frames}, wall={wall_silence:.1f}s)")
                                    await self.gemini_session.send(
                                        input=types.LiveClientContent(turn_complete=True)
                                    )
                                    self._user_was_speaking = False
                                    self._post_speech_silence_frames = 0
                                    self.messages_sent += 1

                        elif msg_type == "text":
                            # Text input from client
                            text = data.get("text", "")
                            if text:
                                await self.gemini_session.send(
                                    input=text,
                                    end_of_turn=True
                                )
                                logger.info(f"💬 Text input: {text}")
                                self.messages_sent += 1

                        elif msg_type == "end_of_turn":
                            # Explicit end-of-turn signal from client (user stopped speaking)
                            await self.gemini_session.send(
                                input=types.LiveClientContent(turn_complete=True)
                            )
                            logger.info("🔚 Client end-of-turn")
                            self._user_was_speaking = False
                            self._post_speech_silence_frames = 0
                            self.messages_sent += 1

                        elif msg_type == "ping":
                            # Heartbeat
                            await self.websocket.send_json({"type": "pong"})

                        elif msg_type == "interrupt":
                            # ── True Barge-In ──────────────────────────────
                            logger.info("⚡ Barge-in: user interrupted AI speech")
                            self._interrupted = True
                            self._user_was_speaking = False
                            self._post_speech_silence_frames = 0
                            # Tell Gemini the current turn is over so it stops
                            # generating and is ready for the next user turn.
                            try:
                                await self.gemini_session.send(
                                    input=types.LiveClientContent(turn_complete=True)
                                )
                                logger.info("🔚 Sent turn_complete to Gemini after barge-in")
                            except Exception as e:
                                logger.warning(f"⚠️ Could not send turn_complete on interrupt: {e}")
                            await self.websocket.send_json({"type": "interrupt_ack"})

                    elif "bytes" in message:
                        # Raw binary audio
                        audio_bytes = message["bytes"]
                        await self.gemini_session.send(
                            input={
                                "data": audio_bytes,
                                "mime_type": "audio/pcm"
                            },
                            end_of_turn=False
                        )
                        self.messages_sent += 1

                except asyncio.TimeoutError:
                    logger.warning(f"⏰ Client timeout: {self.session_id}")
                    break
                except WebSocketDisconnect:
                    logger.info(f"👋 Client disconnected: {self.session_id}")
                    break
                except RuntimeError as e:
                    if "disconnect" in str(e).lower():
                        logger.info(f"👋 Client WebSocket closed: {self.session_id}")
                    else:
                        raise
                    break

        except Exception as e:
            self.errors += 1
            logger.error(f"❌ Client audio handler error: {e}")
            traceback.print_exc()
        finally:
            self.is_active = False

    async def handle_gemini_responses(self):
        """
        Receive responses from Gemini Live API.
        On Vertex AI, session.receive() ends after each turn_complete — it is NOT
        a single persistent generator for the whole session. We must re-call it in
        a while loop to receive subsequent turns.
        """
        try:
            while self.is_active:
                try:
                    async for response in self.gemini_session.receive():

                        # ── Diagnostic ───────────────────────────────────────
                        logger.info(f"📥 RAW response type={type(response).__name__} repr={repr(response)[:300]}")

                        # ── Function / Tool calls ─────────────────────────────
                        # Vertex AI Live: response.tool_call.function_calls (singular)
                        # Wrapped in its own try/except so a crash NEVER kills the loop.
                        try:
                            _tc_obj = getattr(response, 'tool_call', None)
                            _fc_list = []
                            if _tc_obj is not None:
                                _raw_fcs = getattr(_tc_obj, 'function_calls', None)
                                if _raw_fcs:
                                    _fc_list = list(_raw_fcs)
                            if not _fc_list:
                                _fallback = getattr(response, 'tool_calls', None)
                                if _fallback:
                                    _fc_list = list(_fallback)

                            if _fc_list:
                                logger.info(f"🔧 Detected {len(_fc_list)} function call(s): {[tc.name for tc in _fc_list]}")

                            for tool_call in _fc_list:
                                function_name = tool_call.name
                                raw_args = getattr(tool_call, 'args', {}) or {}
                                try:
                                    function_args = dict(raw_args)
                                except Exception:
                                    function_args = {}
                                call_id = str(getattr(tool_call, 'id', '') or '')
                                logger.info(f"🔧 Calling: {function_name}({function_args}) id={call_id!r}")

                                try:
                                    if function_name not in self.functions:
                                        logger.warning(f"⚠️ Unknown function: {function_name}")
                                        continue

                                    result = await self.functions[function_name](**function_args)
                                    self.functions_executed += 1
                                    logger.info(f"✅ Function result: {result}")

                                    safe_result = json.loads(json.dumps(result, default=str))

                                    fr_kwargs: Dict[str, Any] = {
                                        "name": function_name,
                                        "response": {"output": safe_result},
                                    }
                                    if call_id:
                                        fr_kwargs["id"] = call_id

                                    await self.gemini_session.send(
                                        input=types.LiveClientToolResponse(
                                            function_responses=[types.FunctionResponse(**fr_kwargs)]
                                        )
                                    )
                                    logger.info(f"📤 Tool response sent for {function_name}")

                                    await self.websocket.send_json({
                                        "type": "function_executed",
                                        "function": function_name,
                                        "args": function_args,
                                        "result": safe_result,
                                    })
                                    logger.info(f"✅ Function executed & UI notified: {function_name}")

                                except Exception as fn_err:
                                    logger.error(f"❌ Error executing {function_name}: {fn_err}")
                                    traceback.print_exc()
                                    try:
                                        err_kwargs: Dict[str, Any] = {
                                            "name": function_name,
                                            "response": {"output": {"error": str(fn_err)}},
                                        }
                                        if call_id:
                                            err_kwargs["id"] = call_id
                                        await self.gemini_session.send(
                                            input=types.LiveClientToolResponse(
                                                function_responses=[types.FunctionResponse(**err_kwargs)]
                                            )
                                        )
                                    except Exception:
                                        pass

                        except Exception as tc_err:
                            logger.error(f"❌ Tool-call dispatch error: {tc_err}")
                            traceback.print_exc()

                        # ── Audio output ──────────────────────────────────────
                        # Skip audio that arrives in the SAME response as a tool call —
                        # that is the model "pre-announcing" what it's about to do, which
                        # causes it to repeat itself once the tool result comes back.
                        if _fc_list and hasattr(response, 'data') and response.data:
                            logger.debug("🔇 Dropping pre-tool audio to prevent double-speech")
                        elif hasattr(response, 'data') and response.data:
                            logger.info(f"🔊 Gemini audio chunk: {len(response.data)} bytes")
                            if self._interrupted:
                                logger.debug("🔇 Dropping audio chunk (barge-in)")
                                continue
                            await self.websocket.send_json({"type": "ai_generating"})
                            audio_data = response.data
                            try:
                                if isinstance(audio_data, bytes):
                                    sample = audio_data[:20] if len(audio_data) >= 20 else audio_data
                                    if all(b >= 43 and b <= 122 for b in sample) and len(audio_data) > 4:
                                        pad = len(audio_data) % 4
                                        if pad:
                                            audio_data += b'=' * (4 - pad)
                                        audio_bytes = base64.b64decode(audio_data)
                                    else:
                                        audio_bytes = audio_data
                                elif isinstance(audio_data, str):
                                    pad = len(audio_data) % 4
                                    if pad:
                                        audio_data += '=' * (4 - pad)
                                    audio_bytes = base64.b64decode(audio_data)
                                else:
                                    logger.warning(f"⚠️ Unexpected audio type: {type(audio_data)}")
                                    continue
                                if len(audio_bytes) > 44 and audio_bytes.startswith(b'RIFF'):
                                    audio_bytes = audio_bytes[44:]
                                await self.websocket.send_json({
                                    "type": "audio",
                                    "data": base64.b64encode(audio_bytes).decode('utf-8'),
                                    "sample_rate": RECEIVE_SAMPLE_RATE,
                                    "mime_type": "audio/pcm"
                                })
                                self.messages_sent += 1
                            except Exception as e:
                                self.errors += 1
                                logger.error(f"❌ Audio processing failed: {e}")
                                continue

                        # ── Text transcript ───────────────────────────────────
                        if hasattr(response, 'text') and response.text:
                            logger.info(f"💬 Gemini: {response.text[:80]}")
                            await self.websocket.send_json({"type": "transcript", "text": response.text})
                            self.messages_sent += 1

                        # ── Turn completion ───────────────────────────────────
                        if hasattr(response, 'server_content') and response.server_content:
                            sc = response.server_content
                            if getattr(sc, 'turn_complete', False):
                                logger.info("✅ Turn complete")
                                await self.websocket.send_json({"type": "turn_complete"})
                            if getattr(sc, 'interrupted', False):
                                logger.info("⚡ Gemini interrupted")
                                await self.websocket.send_json({"type": "interrupted"})

                    # receive() exhausted for this turn — loop to await next turn
                    logger.info("🔄 receive() ended — ready for next user turn")

                except RuntimeError as rte:
                    if "disconnect" in str(rte).lower():
                        logger.info("🔌 Gemini session disconnected (RuntimeError)")
                        break
                    # Non-fatal RuntimeError — log and continue to next turn
                    logger.error(f"❌ RuntimeError in receive loop: {rte}")
                    await asyncio.sleep(0.1)

                except Exception as turn_err:
                    # An error in a single turn should not kill the whole session.
                    # Log it and let the outer while loop continue.
                    logger.error(f"❌ Error during receive turn: {turn_err}")
                    traceback.print_exc()
                    if not self.is_active:
                        break
                    await asyncio.sleep(0.1)

        except asyncio.CancelledError:
            logger.info("🔄 Gemini response handler cancelled")
        except Exception as e:
            self.errors += 1
            logger.error(f"❌ Gemini response handler error: {e}")
            traceback.print_exc()
            self.is_active = False


@router.websocket("/ws-test")
async def websocket_test_endpoint(websocket: WebSocket):
    """
    Minimal WebSocket test endpoint - no dependencies
    Use this to verify WebSocket connectivity works
    """
    try:
        await websocket.accept()
        await websocket.send_json({
            "type": "test",
            "message": "WebSocket connection successful!",
            "url": "/api/voice/ws-test"
        })
        await websocket.close()
        logger.info("✅ Test WebSocket connection successful")
    except Exception as e:
        logger.error(f"❌ Test WebSocket error: {e}")


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    """
    WebSocket endpoint for Gemini Live voice assistant
    Production-ready with comprehensive error handling
    """
    client_host = websocket.client.host if websocket.client else "unknown"
    logger.info(f"🔌 New WebSocket connection from {client_host}")

    try:
        # Accept connection
        await websocket.accept()
        logger.info(f"✅ WebSocket accepted from {client_host}")

        # Check session limits
        if len(active_sessions) >= 50:
            logger.warning(f"⚠️ Session limit reached ({len(active_sessions)}/50)")
            await websocket.send_json({
                "type": "error",
                "error": "Server at capacity. Please try again later."
            })
            await websocket.close(code=1008, reason="Server at capacity")
            return

        # Create and initialize session
        session = GeminiLiveSession(websocket, db)
        active_sessions[session.session_id] = session

        if await session.initialize():
            logger.info(f"✅ Session initialized: {session.session_id}")
            await session.start()
        else:
            logger.error(f"❌ Session initialization failed")
            await websocket.send_json({
                "type": "error",
                "error": "Failed to initialize AI session"
            })
            await websocket.close(code=1008, reason="Initialization failed")

    except WebSocketDisconnect:
        logger.info(f"👋 WebSocket disconnected: {client_host}")
    except Exception as e:
        logger.error(f"❌ WebSocket error: {e}")
        traceback.print_exc()
        try:
            await websocket.close(code=1011, reason=f"Server error: {str(e)}")
        except:
            pass


# ==========================================
# Health & Monitoring Endpoints
# ==========================================

@router.get("/test")
async def test_endpoint():
    """Simple test to verify router is reachable"""
    return {
        "status": "ok",
        "message": "Voice router is reachable",
        "endpoints": {
            "websocket_test": "/api/voice/ws-test",
            "websocket_main": "/api/voice/ws",
            "status": "/api/voice/live/status"
        }
    }


@router.get("/live/status")
async def get_live_status():
    """Get Gemini Live API status and configuration"""
    return {
        "status": "ready",
        "model": GEMINI_LIVE_MODEL,
        "available": bool(settings.gemini_api_key),
        "sessions": {
            "active": len(active_sessions),
            "max": 50,
            "utilization_percent": (len(active_sessions) / 50) * 100
        },
        "voice_config": {
            "current_voice": "Puck",
            "available_voices": ["Puck", "Aoede", "Charon", "Kore", "Fenrir"],
            "polyglot_support": True,
            "languages": ["Arabic", "French", "English"]
        },
        "audio_config": {
            "input_sample_rate": SEND_SAMPLE_RATE,
            "output_sample_rate": RECEIVE_SAMPLE_RATE,
            "input_format": "PCM 16-bit mono",
            "output_format": "PCM 16-bit mono"
        }
    }


@router.get("/live/sessions")
async def get_active_sessions():
    """Get active session information"""
    sessions_info = {}
    for session_id, session in active_sessions.items():
        sessions_info[session_id] = {
            "start_time": datetime.fromtimestamp(session.start_time).isoformat(),
            "duration_seconds": round(time.time() - session.start_time, 1),
            "messages_sent": session.messages_sent,
            "messages_received": session.messages_received,
            "functions_executed": session.functions_executed,
            "errors": session.errors,
            "is_active": session.is_active
        }

    return {
        "active_sessions": list(active_sessions.keys()),
        "count": len(active_sessions),
        "stats": sessions_info
    }


@router.get("/live/metrics")
async def get_live_metrics():
    """Get performance metrics"""
    total_messages = sum(s.messages_sent + s.messages_received for s in active_sessions.values())
    total_functions = sum(s.functions_executed for s in active_sessions.values())
    total_errors = sum(s.errors for s in active_sessions.values())

    return {
        "status": "operational",
        "active_sessions": len(active_sessions),
        "total_messages": total_messages,
        "total_functions_executed": total_functions,
        "total_errors": total_errors,
        "connection_quality": "good" if total_errors == 0 else "degraded",
        "features": {
            "vad_enabled": True,
            "auto_silence_detection": True,
            "barge_in_support": True,
            "audio_enhancement": "optional",
            "multimodal": True,
            "function_calling": True
        }
    }
