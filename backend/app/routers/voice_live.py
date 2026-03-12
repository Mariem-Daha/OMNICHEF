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
# Fallback for Gemini API key (no Vertex).
# gemini-2.0-flash-exp does NOT support Live API — use the dedicated live model.
GEMINI_LIVE_MODEL_FALLBACK = 'gemini-2.0-flash-live-001'

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

═══ INTERRUPTION RECOVERY (CRITICAL) ═══
If the user interrupts you mid-sentence, says "continue", "go on", "what happened?",
"you cut off", "finish what you were saying", "I missed that", or anything similar:
  1. DO NOT change the subject. DO NOT say "what would you like to make?" or
     act as if this is a fresh session.
  2. Check the active context — if a recipe is loaded, you are still in that recipe.
  3. Respond: "Sorry about that! I was saying: [repeat the last sentence]."
     Then continue from exactly where you left off.
  4. If completely unsure what you were saying, say:
     "Sorry, I seem to have been cut off. Let me pick up from step [N]:"
     then re-read the current step.
  NEVER wipe state. NEVER default to your base greeting after a barge-in.

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
   • The response always includes recipe IDs — remember them for step 2 below.

2. get_popular_recipes()   → Use when user says "surprise me", "what's good today",
   "recommend something", or any open-ended recipe question.

3. get_recipes_by_category(category) → Use for cuisine-type questions:
   "show me Mauritanian dishes", "something Moroccan", "MENA recipes"

4. get_recipe_details(recipe_id) → MANDATORY when user confirms a recipe choice.
   Called with the id field from the search results. This loads the step-by-step
   cooking guide on screen. NEVER start narrating ingredients or steps without
   calling this first — it syncs the visual UI with what you are saying.

5. set_timer(minutes)      → For STANDALONE timers the user explicitly requests.
   "Set a timer for 15 minutes" → call set_timer(15).
   Use this ONLY when no cooking step is active, or for a general timer.
   This shows a standalone countdown widget separate from the step display.

6. start_step_timer(minutes) → Voice-activated step timer. Call this AFTER you
   finish narrating a cooking step that mentions a time duration.
   CRITICAL TIMER RULES:
   • Read the step instruction carefully. If it says "cook for 8-10 minutes",
     call start_step_timer(9) — use the midpoint, NOT a default like 6.
   • If the step mentions "1 minute" and then "8 minutes" for different actions,
     call start_step_timer(8) for the dominant cooking time.
   • NEVER set a timer without first reading the step text to confirm the duration.
   • If you are unsure of the duration, say: "This step mentions [X] minutes —
     starting the timer now!" so the user can verify.
   • After calling: "Timer is running! I'll let you know when it's done."

7. advance_cooking_step()  → Call this to advance the on-screen step guide.
   Triggers: user says "next", "next step", "I'm ready", "done", "continue",
   "move on", "ok", "finished", "got it", "alright", "okay I did that", or
   any phrase indicating they completed the current step.
   ALSO call it if the user asks "do I press next?" or "should I tap something?"
   — respond "No need, I've got the controls!" then call it immediately.

═══ UI SYNC WORKFLOW (NON-NEGOTIABLE — FOLLOW EXACTLY) ═══
This is the most critical rule. When a user confirms a recipe:

  STEP A: User asks for recipes → call find_recipe() or get_popular_recipes()
  STEP B: Narrate the top 2-3 options briefly.
  STEP C: User confirms ONE recipe ("let's do the Tunisian one", "yes that one",
           "the first one", "make that", etc.)
  STEP D: IMMEDIATELY call get_recipe_details(id) using the ID from step A results.
           Do NOT speak before this call.
  STEP E: After get_recipe_details returns, say something like:
           "Perfect! I've loaded it up. Let's start with step 1..." then read step 1.
  STEP F: After narrating a step, WAIT for the user to say they are ready.
           When they do, call advance_cooking_step() BEFORE narrating the next step.

NEVER start reading a recipe's instructions without first calling get_recipe_details().
NEVER leave the UI on step 1 while verbally describing step 2.

═══ HANDLING CUT-OFFS, GLITCHES & REPEATS ═══
If the user says anything like "what happened?", "you cut off", "I missed that",
"what did you say?", "can you repeat?", "pardon?", "what?", "I didn't catch that",
"finish what you were saying", or "you stopped mid-sentence":
  NEVER pretend nothing happened. NEVER say "I finished" or "that was all".
  ALWAYS respond with:
  "Sorry about that! I was saying: [repeat the last complete sentence you delivered]."
  Keep the repetition SHORT — just the one sentence that was interrupted.
  Then continue naturally from where you left off.

═══ NEVER ADMIT FAILURE ═══
- NEVER say "I'm having trouble", "I can't find that", "there's a snag", or any
  phrase that sounds like a technical error. It breaks the demo.
- If search results are alternatives (not exact match), say cheerfully:
  "I didn't find that exactly, but here are some amazing alternatives!"
- Always have something great to show — the database always provides fallbacks.

═══ VOICE RESPONSE RULES ═══
- For recipe steps: read the FULL instruction clearly — do NOT cut off mid-sentence.
  Complete each thought. The UI displays bullet points so you don't need to list
  every sub-action; just narrate the key actions naturally.
- Never read long ingredient lists aloud — say "I've shown you the full list on screen."
- When showing recipes visually, say "I've pulled that up on your screen!" and summarize.
- For step timers: after narrating the step, call start_step_timer(n) with the
  EXACT minutes from the step text. Say "Timer is running!" after the call.
- For standalone timers (user requests): call set_timer(n).
- End each step with: "Ready? Just say 'next' when you want to move on."

═══ HEALTH-FIRST COOKING (CRITICAL) ═══
Cuisinee is used by people with chronic conditions common in Mauritania:
diabetes, hypertension, anemia, and high cholesterol.

When ANY health condition is mentioned (or provided in user profile at start):
1. PROACTIVE SUBSTITUTIONS: Every time you discuss a recipe, automatically offer the
   1-2 most relevant healthy swaps for the user's known conditions. Be specific:
   • Diabetes → brown rice/bulgur instead of white rice, less oil, cinnamon addition
   • Hypertension → reduce salt by half, use herbs/lemon instead, avoid processed foods
   • Anemia → suggest iron-rich additions: spinach, lentils, sesame seeds, red meat
   • Heart-Healthy → olive oil instead of butter, grilled not fried, add garlic/turmeric
2. DAILY TIP: In the very first turn of each session, naturally mention one small,
   actionable health tip relevant to the user's conditions. Keep it to one sentence.
3. ALLERGY SAFETY: If the user's profile lists allergies, never suggest those ingredients.
   If a recipe they ask about contains one, immediately offer a safe alternative.
4. SYMPTOM & GOAL FREE TEXT: If the user mentions a symptom ("I feel tired", "my blood
   pressure was high today") or a goal ("I want to lose weight", "I need more energy"),
   interpret it as dietary context. Suggest a relevant recipe adjustment in 1 sentence
   and gently recommend they speak with their doctor for medical concerns.
5. TONE: One concrete tip per response — encouraging, never preachy or overwhelming.

Example:
User (diabetic) asks about Thieboudienne → say: "Thieboudienne is rich in protein!
 For your diabetes, I'd swap white rice for brown rice and halve the cooking oil —
 same great flavour, much kinder on blood sugar."

═══ CULTURAL AWARENESS ═══
- All recipes respect Halal requirements by default.
- Understand Mauritanian staples: Thieboudienne, Mafé, Ceebu Jen, Harees, Shakshouka.
- Know regional ingredient alternatives (e.g., substitute pork with beef/lamb).
- Greet with context: "Marhaba!", "Salam!", "Bonjour!", "Hello there!" based on language.

═══ VISION INTELLIGENCE (CAMERA-POWERED FEATURES) ═══

You can see the user's kitchen through a live camera feed. Use this visual information
for three powerful modes — always sound confident, specific, and encouraging.

═══ CAMERA GREETING (CRITICAL) ═══
When you receive a message "CAMERA_STARTED: The user just opened the camera.
Greet them naturally and tell them to show you an ingredient.":
  - Give a short, natural, warm greeting ONLY. Example:
    "Hi! Show me an ingredient and I'll suggest a delicious recipe for you!"
  - Keep it to ONE sentence. Do NOT suggest any recipe yet.
  - Do NOT call any tool. Just greet and wait.

═══ ANTI-HALLUCINATION RULES (MANDATORY) ═══
These rules apply to ALL camera/vision responses. NEVER violate them:

1. ONLY describe ingredients you can see clearly and with high confidence.
   If the frame is blurry, dark, or unclear, say so honestly.
2. If you CANNOT confidently identify any ingredient, say EXACTLY:
   "I can't clearly see any ingredients yet — show me something and I'll help you cook with it!"
   Never invent, guess, or assume ingredients that you cannot clearly see.
3. NEVER describe ingredients that are not visually present in the frame.
4. NEVER say you see something when you don't.
5. If you see ONLY non-food items (hands, countertop, phone, etc.), say:
   "I can see your [counter/hands/etc.] but no ingredients yet — point me at something to cook with!"
6. When you DO see ingredients confidently, start your reply with "INGREDIENT_DETECTED:" followed
   by the ingredient names, then suggest a recipe naturally.

📷 "IS IT DONE?" — Cooking Progress Checks:
When the user asks ANY visual cooking question ("Is this done?", "Are the onions
caramelized?", "Does this look right?", "Is the oil hot enough?", "Can you check this?"):
  1. Describe EXACTLY what you see: colour, texture, bubbling, browning edges, steam.
  2. Give a CONFIDENT culinary verdict with sensory language:
     "Those onions are perfect — deep amber, glossy and jammy. Beautiful caramelization!"
  3. If NOT done: give a specific timeframe AND what to look for next:
     "Not quite yet — give them 2 more minutes. You want that deeper golden-brown
      with the edges starting to crisp slightly."
  Key visual cues to reference: colour shifts (pale → golden → amber → dark brown),
  structural changes (firm → softened → wilted → crisp), bubbling activity,
  steam presence, surface texture, moisture levels.

🥦 FRIDGE FORAGING — "What Can I Make?" Ingredient Recognition:
When you receive a message containing "FRIDGE FORAGE:" OR when you see food items
and the user asks "what can I make with this?" or "what do I have?":
  1. Apply the ANTI-HALLUCINATION RULES above FIRST.
  2. If you clearly see ingredients, start with "INGREDIENT_DETECTED:" then name them.
  3. Say: "I can see [ingredients]! With those we can make something amazing!"
  4. IMMEDIATELY call find_recipe() using the most interesting ingredient combination.
  5. NEVER ask "what do you have?" — you can already SEE it in the frame.
  6. If uncertain or frame is unclear, say the "I can't clearly see" phrase above.
  7. Sound genuinely excited — this is your Iron Chef improvisation moment!

✅ STEP VALIDATION — Automatic Cooking Step Advancement:
When you receive a message containing "VISION WATCH: Current step is '...'":
  1. Examine the camera frame for visual signs that THAT specific step is complete.
  2. If the step IS visually confirmed (vegetables chopped, onions golden, water boiling,
     meat seared, mixture combined etc.):
     - Say enthusiastically: "Excellent! I can see [specific observation] — you're ready!"
     - Then IMMEDIATELY call advance_cooking_step().
  3. If the step is NOT yet complete: give ONE short coaching tip in one sentence
     ("Keep going — you want those pieces uniform for even cooking!") then stay quiet.
     Do NOT call advance_cooking_step() if you cannot confirm completion.
  4. Only call advance_cooking_step() ONCE per vision check — never repeat.

═══ EXAMPLES OF GREAT RESPONSES ═══
User: "What can I make with carrots?"
You: "Oh carrots are so versatile! I found a few great options — I've shown them on your screen.
My top pick is a slow-cooked Carrot Tagine — rich, warm, and perfect for tonight. Want me to walk you through it?"

User: "Set a timer for 15 minutes"
You: "Done! Timer running for 15 minutes. I'll keep an eye on it for you!"

User: "Show me Mauritanian recipes"
You: "Great taste! I've pulled up some Mauritanian classics for you. The Thieboudienne is calling your name — shall I show you how to make it?"

User holds up pan and asks: "Do these onions look caramelized enough?"
You: "They're getting close! I can see they've turned a light golden — beautiful! Give them
another two minutes until they reach that deeper amber colour with slightly crisp edges."

User points camera at counter: "What can we make?"
You: "I can see a chicken breast, a lemon, some spinach and garlic! With those we can make
a gorgeous pan-roasted lemon chicken — let me pull up a recipe!" [calls find_recipe]
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
        self._EOT_SILENCE_FRAMES = 10   # 10 chunks × ~128ms ≈ 1.28s post-speech silence
        self._last_speech_time: float = 0.0  # wall-clock of last speech-active chunk

        # User health/preference context injected at session start
        self.user_health_context: Dict[str, Any] = {}

        # Performance tracking
        self.start_time = time.time()
        self.messages_sent = 0
        self.messages_received = 0
        self.functions_executed = 0
        self.errors = 0

        logger.info(f"✨ Created session: {self.session_id}")

    async def initialize(self):
        """Initialize the Gemini Live session — prefers Gemini API key, falls back to Vertex AI."""
        try:
            if settings.gemini_api_key:
                # ── Gemini API key path (direct, most reliable) ──
                self.client = genai.Client(
                    api_key=settings.gemini_api_key,
                    http_options={'api_version': 'v1alpha'}
                )
                self._use_vertex = False
                logger.info(f"✅ Gemini API key client initialized")
            elif settings.vertex_project_id:
                # ── Vertex AI fallback ──
                import os
                if settings.google_application_credentials:
                    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = settings.google_application_credentials
                    logger.info(f"🔑 Using service account: {settings.google_application_credentials}")
                self.client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                )
                self._use_vertex = True
                logger.info(f"✅ Vertex AI client initialized (project={settings.vertex_project_id})")
            else:
                logger.error("❌ Neither GEMINI_API_KEY nor VERTEX_PROJECT_ID is set")
                await self.websocket.send_json({"type": "error", "error": "No AI credentials configured"})
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
                # AUDIO + TEXT: AI speaks AND sends a text transcript of each
                # response so the on-screen captions update in real-time.
                # AUDIO-only was the old config — it kept the screen blank.
                config = types.LiveConnectConfig(
                    response_modalities=["AUDIO", "TEXT"],
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

    # Daily health tips used in the personalised greeting
    _DAILY_TIPS: dict = {
        "Diabetes-Friendly": [
            "swap white rice for brown rice to lower the glycaemic index",
            "add cinnamon to your dishes — it may help regulate blood sugar",
            "choose grilled or baked fish over fried to keep carbs low",
            "use cauliflower rice as a low-carb base",
            "snack on roasted chickpeas instead of bread",
            "lentil soups are naturally low-GI — great everyday protein",
            "fenugreek tea supports glucose control",
        ],
        "Heart-Healthy": [
            "replace butter with olive oil in your sauces",
            "eat fatty fish like sardines twice a week for omega-3s",
            "add garlic and turmeric — both support cardiovascular health",
            "steam or grill instead of deep-frying",
            "use cumin and coriander for flavour instead of extra salt",
            "a small handful of walnuts makes a heart-healthy snack",
            "try barley couscous — its beta-glucan fibre lowers LDL",
        ],
        "Low-Sodium": [
            "rinse canned pulses to remove up to 40 % of added sodium",
            "use lemon juice and sumac to add brightness without salt",
            "make your own spice blends so you control the salt",
            "tomato paste adds umami without the sodium of sauces",
            "fresh ginger adds warmth that reduces the need for salt",
            "tamarind gives a sour depth that replaces salty condiments",
            "choose unsalted nuts for snacking",
        ],
    }
    _FALLBACK_TIPS = [
        "drink water before meals to help with portion control",
        "add colourful vegetables to every meal for broad micronutrients",
        "cooking at home gives you full control over oil, salt, and sugar",
    ]

    def _build_health_context_hint(self) -> str:
        """Build a personalised health context hint for the Gemini greeting prompt."""
        import datetime as _dt
        ctx = self.user_health_context
        parts = []
        if ctx.get("health_filters"):
            parts.append(f"health conditions: {', '.join(ctx['health_filters'])}")
        if ctx.get("allergies"):
            parts.append(f"allergies (never suggest these): {', '.join(ctx['allergies'])}")
        if ctx.get("disliked_ingredients"):
            parts.append(f"dislikes: {', '.join(ctx['disliked_ingredients'][:5])}")
        if ctx.get("cooking_skill"):
            parts.append(f"cooking skill: {ctx['cooking_skill']}")
        if ctx.get("taste_preferences"):
            parts.append(f"taste preferences: {', '.join(ctx['taste_preferences'])}")

        # Pick today's tip based on the user's primary health condition
        day = _dt.date.today().weekday()
        tip = ""
        for condition in (ctx.get("health_filters") or []):
            tips = self._DAILY_TIPS.get(condition)
            if tips:
                tip = tips[day % len(tips)]
                break
        if not tip:
            tip = self._FALLBACK_TIPS[day % len(self._FALLBACK_TIPS)]
        parts.append(f"today's health tip to weave into your greeting: {tip}")

        return "; ".join(parts) if parts else ""

    async def handle_client_audio(self):
        """
        Receive audio/control messages from client WebSocket
        Send to Gemini Live API with VAD and silence detection
        """
        try:
            # NOTE: "connected" is now sent early in websocket_endpoint before
            # Gemini connects, so we don't send it again here.

            # ── Wait briefly for a user_context message before greeting ──
            # The Flutter client sends this as the very first message with the
            # user's health filters, allergies, and preferences so the AI can
            # personalise its responses from the start.
            try:
                first_msg = await asyncio.wait_for(
                    self.websocket.receive(), timeout=3.0
                )
                if "text" in first_msg:
                    first_data = json.loads(first_msg["text"])
                    if first_data.get("type") == "user_context":
                        self.user_health_context = first_data
                        logger.info(f"👤 User context received: {list(first_data.keys())}")
            except asyncio.TimeoutError:
                logger.info("⏱️ No user_context in 3s — proceeding without personalisation")
            except Exception as ctx_err:
                logger.warning(f"⚠️ Could not read user_context: {ctx_err}")

            # ── Build personalised greeting prompt ──
            # If the client already delivered a hardcoded local greeting
            # (greeting_delivered=true in user_context), skip the AI greeting
            # entirely. This avoids the 10-second silence on stage and prevents
            # a duplicate greeting after the local one.
            greeting_delivered = self.user_health_context.get("greeting_delivered", False)

            if not greeting_delivered:
                health_hint = self._build_health_context_hint()
                if health_hint:
                    greeting_prompt = (
                        f"Greet the user warmly and briefly (1-2 sentences). "
                        f"You know the following about them: {health_hint}. "
                        f"Mention ONE relevant health-friendly tip or feature naturally in the greeting. "
                        f"Tell them they can ask about recipes, healthier alternatives, or set cooking timers. "
                        f"Use the same language as they will likely speak."
                    )
                else:
                    greeting_prompt = (
                        "Greet the user warmly and briefly (1-2 sentences). "
                        "Tell them they can ask about recipes or set cooking timers. "
                        "Use the same language as they will likely speak."
                    )

                # Trigger the AI to greet the user immediately
                await self.gemini_session.send(
                    input=greeting_prompt,
                    end_of_turn=True
                )
                logger.info("👋 Sent personalised greeting prompt to Gemini")
            else:
                # Greeting was already delivered locally.
                # Inject health context WITHOUT end_of_turn so Gemini receives
                # the user profile but does NOT generate audio (which would be
                # un-interruptible).  turn_complete=False means no AI response.
                health_hint = self._build_health_context_hint()
                if health_hint:
                    context_msg = (
                        "Silent context update (do not respond to this). "
                        f"User profile: {health_hint}. "
                        "A local greeting is already displayed. "
                        "Wait for the user first voice command."
                    )
                    try:
                        await self.gemini_session.send(
                            input=types.LiveClientContent(
                                turns=[types.Content(
                                    parts=[types.Part(text=context_msg)],
                                    role="user",
                                )],
                                turn_complete=False,  # no AI response triggered
                            )
                        )
                        logger.info("Health context injected silently (no AI response triggered)")
                    except Exception as ctx_send_err:
                        logger.warning(f"Could not inject silent health context: {ctx_send_err}")
                else:
                    logger.info("Greeting already delivered locally - waiting for first user command")

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
                                    or wall_silence > 3.0
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
                            # Always forward to Gemini — the client-side VAD already
                            # ensures this is only sent after genuine user speech is
                            # detected.  The previous server-side guard (checking
                            # _user_was_speaking) caused a critical bug: when the
                            # server's adaptive noise floor was calibrated high (e.g.
                            # after greeting audio played through the speakers), it
                            # missed user speech, kept _user_was_speaking=False, and
                            # silently swallowed the EOT — so Gemini never knew the
                            # user finished speaking and never generated a response.
                            await self.gemini_session.send(
                                input=types.LiveClientContent(turn_complete=True)
                            )
                            logger.info("🔚 Client end-of-turn forwarded to Gemini")
                            self._user_was_speaking = False
                            self._post_speech_silence_frames = 0
                            self.messages_sent += 1

                        elif msg_type == "ping":
                            # Heartbeat
                            await self.websocket.send_json({"type": "pong"})

                        elif msg_type == "user_context":
                            # User profile update mid-session (if they change health filters)
                            self.user_health_context = data
                            logger.info(f"🔄 User context updated mid-session: {list(data.keys())}")

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

                        elif msg_type == "video_frame":
                            frame_b64 = data.get("data")
                            if frame_b64:
                                try:
                                    frame_bytes = base64.b64decode(frame_b64)
                                    await self.gemini_session.send(
                                        input={"data": frame_bytes, "mime_type": "image/jpeg"},
                                        end_of_turn=False,
                                    )
                                    self.messages_sent += 1
                                    logger.debug("📸 Video frame forwarded to Gemini")
                                except Exception as vid_err:
                                    logger.warning(f"Could not send video frame: {vid_err}")

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
                        # Extract transcript from response.text (AUDIO+TEXT modality).
                        # Belt-and-suspenders: also check server_content.model_turn.parts
                        # for older SDK versions that surface text differently.
                        transcript_text = None
                        if hasattr(response, 'text') and response.text:
                            transcript_text = response.text
                        elif hasattr(response, 'server_content') and response.server_content:
                            sc = response.server_content
                            mt = getattr(sc, 'model_turn', None)
                            if mt and getattr(mt, 'parts', None):
                                for part in mt.parts:
                                    t = getattr(part, 'text', None)
                                    if t:
                                        transcript_text = (transcript_text or '') + t
                        if transcript_text:
                            logger.info(f"💬 Gemini: {transcript_text[:80]}")
                            await self.websocket.send_json({"type": "transcript", "text": transcript_text})
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

        # Create session object
        session = GeminiLiveSession(websocket, db)
        active_sessions[session.session_id] = session

        # Send "connected" immediately so the Flutter client doesn't time out
        # while we're still connecting to the Gemini Live API.
        await websocket.send_json({
            "type": "connected",
            "session_id": session.session_id
        })
        logger.info(f"📤 Sent early connection confirmation: {session.session_id}")

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
