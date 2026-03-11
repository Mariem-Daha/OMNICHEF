"""AI Service for Cuisinee cooking assistant using Gemini (google.genai SDK)."""

from google import genai
from google.genai import types
from ..config import get_settings

settings = get_settings()

# System prompt for the cooking assistant (base — no user context)
_BASE_SYSTEM_PROMPT = """You are Cuisinee, a friendly and knowledgeable AI cooking assistant specializing in Mauritanian and MENA (Middle East & North Africa) cuisine. Your personality is warm, helpful, and culturally aware.

Key traits:
- Greet users with "Assalamu alaikum" when appropriate
- Deep knowledge of Mauritanian dishes like Thieboudienne, Yassa, Mafé, and Couscous
- Expertise in MENA cuisines including Moroccan, Lebanese, Egyptian, and Tunisian
- Health-conscious cooking advice (diabetes-friendly, low-sodium, heart-healthy options)
- Practical substitution suggestions for hard-to-find ingredients
- Step-by-step cooking guidance with helpful tips
- Knowledge of halal cooking practices

When responding:
1. Be concise but informative (keep responses under 200 words unless detailed steps are requested)
2. Use bullet points and emojis to make responses scannable
3. Offer follow-up suggestions to keep the conversation helpful
4. If asked about a recipe, briefly describe it and offer to provide full details
5. For health-related questions, always recommend consulting a healthcare provider for medical advice

Remember: You're helping busy home cooks in Mauritanian and MENA households make delicious, healthy meals!"""

# Keep SYSTEM_PROMPT as alias for legacy callers
SYSTEM_PROMPT = _BASE_SYSTEM_PROMPT


# Daily health tips keyed by condition (cycled by weekday)
_DAILY_TIPS: dict[str, list[str]] = {
    "Diabetes-Friendly": [
        "Swap white rice for brown rice or bulgur to lower the glycaemic index.",
        "Add cinnamon to your morning oatmeal — it may help regulate blood sugar.",
        "Choose grilled or baked fish over fried to keep carbs low.",
        "Use cauliflower rice as a base for Thieboudienne for a low-carb twist.",
        "Snack on roasted chickpeas instead of bread between meals.",
        "Lentil soups are naturally low-GI — a great everyday protein source.",
        "Choose fenugreek tea over sugary drinks — it supports glucose control.",
    ],
    "Heart-Healthy": [
        "Replace butter with olive oil in sauces — your heart will thank you.",
        "Eat fatty fish like sardines or mackerel twice a week for omega-3s.",
        "Add garlic and turmeric generously — both support cardiovascular health.",
        "Steam or grill instead of deep-fry to cut saturated fat.",
        "Use herbs (cumin, coriander, parsley) for flavour instead of extra salt.",
        "Walnuts and almonds make heart-healthy snacks — a small handful goes far.",
        "Try barley couscous — its beta-glucan fibre helps lower LDL cholesterol.",
    ],
    "Low-Sodium": [
        "Rinse canned pulses before using — removes up to 40 % of added sodium.",
        "Use lemon juice and sumac to brighten flavours without salt.",
        "Make your own spice blends so you control every pinch of salt.",
        "Tomato paste adds umami without the sodium of commercial sauces.",
        "Fresh ginger adds a peppery warmth that reduces the need for salt.",
        "Experiment with tamarind for a sour depth that replaces salty condiments.",
        "Choose unsalted nuts and seeds for snacking.",
    ],
    "High-Fiber": [
        "Add a handful of spinach or Swiss chard to any stew for extra fibre.",
        "Choose whole-wheat couscous or pasta — double the fibre of refined versions.",
        "Include a legume (lentils, fava beans, chickpeas) in at least one meal daily.",
        "Eat the skin of roasted vegetables — that's where most fibre hides.",
        "Blend psyllium husk into smoothies for a flavourless fibre boost.",
        "Snack on an apple with almond butter for soluble + insoluble fibre.",
        "Unripe banana slices in porridge provide resistant starch and prebiotic fibre.",
    ],
}

_FALLBACK_TIPS = [
    "Drinking water before meals can help with portion control.",
    "Include colourful vegetables in every meal for a broad range of micronutrients.",
    "Cooking at home gives you full control over oil, salt, and sugar.",
]

import datetime as _dt


def _daily_tip_for(health_filters: list[str]) -> str:
    """Return a single daily tip relevant to the user's top health filter."""
    day = _dt.date.today().weekday()  # 0–6
    for condition in health_filters:
        tips = _DAILY_TIPS.get(condition)
        if tips:
            return tips[day % len(tips)]
    return _FALLBACK_TIPS[day % len(_FALLBACK_TIPS)]


def build_health_system_prompt(user_context: dict | None) -> str:
    """
    Build a personalised system prompt that injects the user's health profile
    so Gemini can proactively suggest substitutions and give tailored advice.
    """
    if not user_context:
        return _BASE_SYSTEM_PROMPT

    health_filters: list[str] = user_context.get("health_filters") or []
    allergies: list[str] = user_context.get("allergies") or []
    disliked: list[str] = user_context.get("disliked_ingredients") or []
    taste: list[str] = user_context.get("taste_preferences") or []
    skill: str = user_context.get("cooking_skill") or "Intermediate"

    # Only augment if we actually have something useful
    if not any([health_filters, allergies, disliked, taste]):
        return _BASE_SYSTEM_PROMPT

    daily_tip = _daily_tip_for(health_filters)

    profile_lines = []
    if health_filters:
        profile_lines.append(f"• Health goals / conditions: {', '.join(health_filters)}")
    if allergies:
        profile_lines.append(f"• Allergies (NEVER suggest these): {', '.join(allergies)}")
    if disliked:
        profile_lines.append(f"• Dislikes (avoid unless asked): {', '.join(disliked[:8])}")
    if taste:
        profile_lines.append(f"• Preferred flavours: {', '.join(taste)}")
    profile_lines.append(f"• Cooking skill: {skill}")
    profile_lines.append(f"• Today's personalised health tip: {daily_tip}")

    health_section = (
        "\n\n"
        "═══ THIS USER'S HEALTH PROFILE (personalised — apply to every response) ═══\n"
        + "\n".join(profile_lines)
        + "\n\n"
        "Rules you MUST follow for this user:\n"
        "1. PROACTIVE SUBSTITUTIONS: Whenever you discuss a recipe, automatically mention\n"
        "   the 1-2 most relevant healthy swaps for their conditions (e.g., brown rice for\n"
        "   diabetes, less salt for hypertension, iron-rich garnish for anemia).\n"
        "2. DAILY TIP: Start the very first response of a new conversation by naturally\n"
        "   weaving in the today's personalised health tip listed above.\n"
        "3. ALLERGY SAFETY: Never suggest any ingredient from their allergy list. If a\n"
        "   requested recipe contains one, immediately offer a safe alternative version.\n"
        "4. SYMPTOM / GOAL FREE TEXT: If the user describes a symptom (e.g., 'I feel tired',\n"
        "   'my blood pressure was high') or a goal (e.g., 'I want to lose weight', 'I need\n"
        "   more energy'), treat it as dietary context. Suggest relevant recipe adjustments\n"
        "   and, when appropriate, recommend they discuss medical concerns with a doctor.\n"
        "5. TONE: Be encouraging, never preachy. One concrete tip per response is enough.\n"
    )

    return _BASE_SYSTEM_PROMPT + health_section


class AIService:
    """Service for AI-powered cooking assistance (text REST endpoints)."""

    def __init__(self):
        self.client: genai.Client | None = None
        self._initialize_client()

    def _initialize_client(self):
        """Initialize the Gemini client."""
        if settings.gemini_api_key:
            try:
                self.client = genai.Client(api_key=settings.gemini_api_key)
            except Exception as e:
                print(f"Error initializing Gemini client: {e}")
        elif settings.vertex_project_id:
            try:
                import os
                if settings.google_application_credentials:
                    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_application_credentials
                self.client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                )
            except Exception as e:
                print(f"Error initializing Vertex AI client: {e}")
        else:
            print("Warning: No GEMINI_API_KEY or VERTEX_PROJECT_ID set. AI features will be limited.")

    async def chat(
        self,
        message: str,
        conversation_history: list[dict] | None = None,
        user_context: dict | None = None,
    ) -> str:
        """
        Generate a response to a user message.

        Args:
            message: The user's message
            conversation_history: Optional list of previous messages for context
            user_context: Optional dict with health_filters, allergies, etc.

        Returns:
            AI-generated response
        """
        if not self.client:
            return self._fallback_response(message)

        try:
            system_prompt = build_health_system_prompt(user_context)

            # Build contents list from history + current message
            contents: list[types.Content] = []
            if conversation_history:
                for msg in conversation_history[-10:]:
                    role = "user" if msg.get("is_user") else "model"
                    contents.append(
                        types.Content(role=role, parts=[types.Part(text=msg.get("content", ""))])
                    )
            contents.append(types.Content(role="user", parts=[types.Part(text=message)]))

            response = await self.client.aio.models.generate_content(
                model="gemini-2.0-flash",
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=0.7,
                    top_p=0.95,
                    max_output_tokens=1024,
                ),
            )
            return response.text or ""

        except Exception as e:
            print(f"Error generating AI response: {e}")
            return self._fallback_response(message)

    def _fallback_response(self, message: str) -> str:
        """Provide a fallback response when AI is unavailable."""
        lower_message = message.lower()

        if "thieb" in lower_message or "fish" in lower_message:
            return """🍽️ Great choice! Thieboudienne is our national dish!

Would you like me to:
1. 📋 Show you the full recipe
2. 👨‍🍳 Start a step-by-step cooking session
3. 💚 Suggest a diabetes-friendly version

Just let me know!"""

        if "healthy" in lower_message or "healthier" in lower_message:
            return """💚 Great choice! Here are some healthier options:

• Use olive oil instead of vegetable oil
• Add more vegetables
• Reduce salt by 50%
• Use brown rice instead of white

Would you like me to modify a recipe with these changes?"""

        if "substitute" in lower_message:
            return """🔄 Here are some substitution ideas:

• **No fish?** Try chicken or tofu
• **No tomato paste?** Use fresh tomatoes
• **Low sodium?** Use herbs for flavor
• **Allergies?** Let me know!

Which ingredient do you need to substitute?"""

        if "leftover" in lower_message or "fridge" in lower_message:
            return """🍳 I'd love to help you use those leftovers!

Tell me what ingredients you have, and I'll suggest some delicious recipes. For example:
"I have chicken, rice, and some vegetables"
"""

        if "diabetes" in lower_message:
            return """💙 I understand! Here are some diabetes-friendly options:

• **Lebanese Fattoush** - Low glycemic, lots of fiber
• **Grilled Fish with Chermoula** - High protein, low carb
• **Shakshuka** - Protein-rich, minimal carbs

Would you like the full recipe for any of these?"""

        return """🍽️ I can help you with that! Here are some ideas:

**Today's Suggestions:**
• 🐟 Thieboudienne (Classic fish & rice)
• 🍋 Chicken Yassa (Lemon-onion chicken)
• 🍳 Shakshuka (Quick & healthy)

What sounds good to you?"""

    async def chat_stream(self, message: str, db_session=None, user_context: dict | None = None):
        """
        Generate a streaming response to a user message with optional tool support.
        """
        if not self.client:
            yield {"type": "text", "content": self._fallback_response(message)}
            return

        try:
            system_prompt = build_health_system_prompt(user_context)

            # For recipe searches, do a DB lookup first
            lower = message.lower()
            if db_session and any(w in lower for w in ["find", "recipe", "make", "cook", "ingredient"]):
                from ..models.recipe import Recipe
                from sqlalchemy import or_, func as sqlfunc
                words = [w for w in lower.split() if len(w) > 3]
                if words:
                    term = f"%{words[0]}%"
                    recipes = db_session.query(Recipe).filter(
                        or_(
                            sqlfunc.lower(Recipe.name).like(term),
                            sqlfunc.lower(Recipe.description).like(term),
                        )
                    ).limit(3).all()
                    if recipes:
                        recipe_data = [
                            {"id": str(r.id), "name": r.name, "description": r.description,
                             "image_url": r.image_url, "cook_time": r.cook_time}
                            for r in recipes
                        ]
                        yield {"type": "tool_response", "tool": "show_recipes", "data": recipe_data}

            response = await self.client.aio.models.generate_content(
                model="gemini-2.0-flash",
                contents=[types.Content(role="user", parts=[types.Part(text=message)])],
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=0.7,
                    max_output_tokens=512,
                ),
            )
            yield {"type": "text", "content": response.text or ""}

        except Exception as e:
            print(f"Error in chat_stream: {e}")
            yield {"type": "text", "content": self._fallback_response(message)}


# Singleton instance
_ai_service: AIService | None = None


def get_ai_service() -> AIService:
    """Get or create AI service singleton."""
    global _ai_service
    if _ai_service is None:
        _ai_service = AIService()
    return _ai_service


