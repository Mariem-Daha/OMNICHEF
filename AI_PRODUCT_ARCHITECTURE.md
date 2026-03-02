# AI Product Architecture - Premium Cooking Assistant
## Production-Level Implementation Plan

---

## 🎯 EXECUTIVE SUMMARY

Transform your cooking assistant from a simple chatbot into an **intelligent agent** that:
- Controls UI through structured intents (not text)
- Enforces tool-first architecture (no hallucination)
- Maintains natural conversation context
- Provides premium UX with smart auto-close behavior

---

## 1. RECOMMENDED ARCHITECTURE

```
┌─────────────────────────────────────────────────────────┐
│                    USER INPUT                           │
│              (Voice/Text from UI)                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              GEMINI LIVE API                            │
│         (With Structured Output Mode)                   │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   TOOLS      │  │  CONTEXT     │  │  SYSTEM      │ │
│  │  (forced)    │  │  (session)   │  │  PROMPT      │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           BACKEND RESPONSE HANDLER                      │
│        (Parse function calls + intents)                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           STRUCTURED JSON RESPONSE                      │
│        {intent, ui_action, speech, auto_close}          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           FRONTEND UI RENDERER                          │
│    Maps intent → Flutter widgets (NOT text)             │
└─────────────────────────────────────────────────────────┘
```

**Key Decision:** Use **Gemini Live API** with **Function Calling** instead of traditional LLM completion.

**Why:**
- Real-time bidirectional streaming
- Built-in tool/function calling
- Enforced structured outputs
- Low latency (< 3s round trip)
- Multi-turn conversation context managed automatically

---

## 2. INTENT SCHEMA (Production-Ready)

### File: `backend/app/schemas/assistant_response.py`

```python
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from enum import Enum

class IntentType(str, Enum):
    # Query intents (require tools)
    SEARCH_RECIPES = "search_recipes"
    SHOW_RECIPE = "show_recipe"
    GET_NUTRITION = "get_nutrition_info"
    CHECK_INVENTORY = "check_inventory"

    # Action intents
    SET_TIMER = "set_timer"
    MODIFY_TIMER = "modify_timer"
    START_COOKING_MODE = "start_cooking_mode"
    SCALE_RECIPE = "scale_recipe"
    ADD_TO_SHOPPING_LIST = "add_to_shopping_list"

    # Navigation intents
    SHOW_FAVORITES = "show_favorites"
    SHOW_HISTORY = "show_history"

    # Conversational intents
    CLARIFICATION_REQUIRED = "clarification_required"
    GENERAL_KNOWLEDGE = "general_knowledge"
    ERROR_STATE = "error_state"

class UIComponentType(str, Enum):
    RECIPE_DETAIL = "recipe_detail"
    RECIPE_GRID = "recipe_grid"
    RECIPE_CAROUSEL = "recipe_carousel"
    TIMER_DISPLAY = "timer_display"
    COOKING_MODE = "cooking_mode"
    INGREDIENT_LIST = "ingredient_list"
    NUTRITION_PANEL = "nutrition_panel"
    DISAMBIGUATION_CARDS = "disambiguation_cards"
    TEXT_RESPONSE = "text_response"

class UIAction(BaseModel):
    component: UIComponentType
    payload: Dict[str, Any]
    transition: str = "fade"  # fade, slide, instant
    mode: str = "replace"  # replace, overlay, split

class AssistantResponse(BaseModel):
    response_id: str = Field(..., description="Unique response ID")
    intent: IntentType
    ui_action: Optional[UIAction] = None
    speech: Optional[str] = Field(None, max_length=200)  # Brief or null
    auto_close: bool = False
    expects_response: bool = False
    context_updates: Optional[Dict[str, Any]] = None

class ToolResult(BaseModel):
    success: bool
    data: Optional[Any] = None
    error: Optional[str] = None
    metadata: Dict[str, Any] = {}
```

---

## 3. TOOL DEFINITIONS (Enforced Tool-First)

### File: `backend/app/modules/function_registry.py` (Enhanced)

```python
from google.genai.types import FunctionDeclaration, Schema, Tool

# CRITICAL: All tools return standardized ToolResult format

RECIPE_SEARCH_TOOL = FunctionDeclaration(
    name="search_recipes",
    description=(
        "Search recipe database by query, ingredients, or cuisine. "
        "MUST be used before mentioning any recipe names. "
        "Returns list of matching recipes with metadata."
    ),
    parameters=Schema(
        type="object",
        properties={
            "query": Schema(type="string", description="Search query (recipe name, ingredient, cuisine)"),
            "filters": Schema(
                type="object",
                properties={
                    "cuisine": Schema(type="array", items=Schema(type="string")),
                    "difficulty": Schema(type="string", enum=["easy", "medium", "hard"]),
                    "max_time_minutes": Schema(type="integer"),
                    "dietary": Schema(type="array", items=Schema(type="string")),
                },
                description="Optional filters"
            ),
            "limit": Schema(type="integer", description="Max results (default: 10)"),
        },
        required=["query"]
    )
)

GET_RECIPE_TOOL = FunctionDeclaration(
    name="get_recipe_by_id",
    description="Fetch complete recipe details including steps, ingredients, nutrition. Use when user references specific recipe.",
    parameters=Schema(
        type="object",
        properties={
            "recipe_id": Schema(type="string", description="Recipe ID from search results"),
        },
        required=["recipe_id"]
    )
)

CREATE_TIMER_TOOL = FunctionDeclaration(
    name="create_timer",
    description="Create a cooking timer with specified duration.",
    parameters=Schema(
        type="object",
        properties={
            "duration_seconds": Schema(type="integer", description="Timer duration in seconds"),
            "label": Schema(type="string", description="Optional label (e.g., 'Boil pasta')"),
        },
        required=["duration_seconds"]
    )
)

GET_ACTIVE_TIMERS_TOOL = FunctionDeclaration(
    name="get_active_timers",
    description="Get all currently active timers.",
    parameters=Schema(type="object", properties={})
)

MODIFY_TIMER_TOOL = FunctionDeclaration(
    name="modify_timer",
    description="Modify existing timer (add/subtract time, pause, resume, cancel).",
    parameters=Schema(
        type="object",
        properties={
            "timer_id": Schema(type="string"),
            "action": Schema(type="string", enum=["add_time", "subtract_time", "pause", "resume", "cancel"]),
            "seconds": Schema(type="integer", description="Time to add/subtract (if applicable)"),
        },
        required=["timer_id", "action"]
    )
)

# Combine into Tool object
COOKING_ASSISTANT_TOOLS = Tool(function_declarations=[
    RECIPE_SEARCH_TOOL,
    GET_RECIPE_TOOL,
    CREATE_TIMER_TOOL,
    GET_ACTIVE_TIMERS_TOOL,
    MODIFY_TIMER_TOOL,
])
```

---

## 4. SYSTEM PROMPT (Production-Grade)

### File: `backend/app/config/system_prompts.py`

```python
COOKING_ASSISTANT_SYSTEM_PROMPT = """
# ROLE
You are an intelligent cooking assistant embedded in a premium recipe app. You are NOT a chatbot — you are an **action-oriented agent** that controls app functionality through structured outputs.

# CORE BEHAVIOR RULES

## 1. TOOL-FIRST ARCHITECTURE (NON-NEGOTIABLE)
- **NEVER mention recipes, timers, or user data without calling tools first**
- If user asks about recipes: ALWAYS call `search_recipes` or `get_recipe_by_id`
- If user mentions timers: ALWAYS call `get_active_timers` first
- **Hallucinating data is a critical failure - you will be penalized**

## 2. OUTPUT FORMAT
You must ALWAYS respond with this exact JSON structure:

{
  "intent": "intent_type",
  "ui_action": {
    "component": "component_name",
    "payload": {...},
    "transition": "fade",
    "mode": "replace"
  },
  "speech": "Brief response text or null",
  "auto_close": true/false,
  "expects_response": true/false
}

## 3. UI OVER TEXT RULE
Your primary output is **structured UI commands**, not conversational text.

WRONG:
User: "Show me pasta carbonara"
Response: {"speech": "Pasta carbonara is a classic Italian dish made with eggs..."}

RIGHT:
User: "Show me pasta carbonara"
→ Call search_recipes(query="pasta carbonara")
→ Return:
{
  "intent": "show_recipe",
  "ui_action": {
    "component": "recipe_detail",
    "payload": {"recipe": <tool_result>}
  },
  "speech": null,
  "auto_close": true
}

## 4. BREVITY
- Speech field: 1-2 sentences max or null
- Never explain what you're doing
- No robotic phrases like "I'll help you with that"
- No filler words

BAD: "Sure! I'd be happy to help you find some delicious pasta recipes. Let me search for those now."
GOOD: "Found 8 pasta recipes." OR null (let UI speak)

## 5. AUTO-CLOSE LOGIC
Set `auto_close: true` when:
- Action is complete (timer set, recipe opened, search shown)
- No follow-up is expected
- User achieved their goal

Set `auto_close: false` when:
- Asking a clarification question
- Multiple steps are needed
- User is likely to continue conversation

## 6. DISAMBIGUATION
If tool returns multiple results:
- IF 1 result → open it directly, speech: null, auto_close: true
- IF 2-5 results → component: "disambiguation_cards", speech: null, auto_close: false
- IF 6+ results → component: "recipe_grid", speech: "Found X recipes", auto_close: false

Never ask "Which one do you want?" — just render the cards.

## 7. CONTEXT AWARENESS
You have access to:
- Conversation history (managed automatically by Gemini Live)
- User preferences (dietary restrictions, skill level)
- Active timers (call get_active_timers if relevant)
- Current recipe (if in cooking mode)

Use this to be intelligent:
User: "Add more time"
→ Call get_active_timers()
→ If 1 timer: modify_timer(timer_id=..., action="add_time", seconds=300)
→ If multiple: ask which one via disambiguation

## 8. NATURAL CONVERSATION
Handle follow-ups naturally:

User: "Show me pasta recipes"
You: [Renders recipe_grid with 12 recipes]
User: "What about the one with bacon?"
You: [Understands "one" = recipe from previous search, "bacon" = pancetta/guanciale]
→ Filter or search within previous results

## 9. ERROR HANDLING
If tool fails:
- DO NOT expose technical errors
- Offer actionable next step

BAD: "Database query failed with error 500"
GOOD:
{
  "intent": "error_state",
  "ui_action": {
    "component": "text_response",
    "payload": {"text": "I couldn't find that recipe. Try searching for something else?"}
  },
  "speech": "Couldn't find that recipe.",
  "auto_close": false
}

## 10. LANGUAGE & CULTURE
- Support Arabic, French, English with proper accents
- Specialize in Mauritanian/MENA cuisine
- Understand local ingredient names (e.g., "thieb" for Thieboudienne)
- Respond in user's language

# INTENT DECISION TREE

User query → Classify intent:

1. Recipe search/show → search_recipes or get_recipe_by_id
2. Timer request → create_timer
3. Timer modification → get_active_timers + modify_timer
4. Cooking guidance → start_cooking_mode (if recipe loaded)
5. Clarification needed → clarification_required (ask question)
6. General knowledge → general_knowledge (brief answer)
7. Error state → error_state (graceful message)

# EXAMPLES

## Example 1: Simple Recipe Request
User: "Show me Thieboudienne"

1. Call search_recipes(query="Thieboudienne")
2. Tool returns: [{"id": "123", "name": "Traditional Thieboudienne", ...}]
3. Respond:
{
  "intent": "show_recipe",
  "ui_action": {
    "component": "recipe_detail",
    "payload": {"recipe": {...}},
    "transition": "slide",
    "mode": "replace"
  },
  "speech": null,
  "auto_close": true,
  "expects_response": false
}

## Example 2: Ambiguous Query
User: "What can I cook with chicken?"

1. Call search_recipes(query="chicken", limit=20)
2. Tool returns: [20 recipes]
3. Respond:
{
  "intent": "search_recipes",
  "ui_action": {
    "component": "recipe_grid",
    "payload": {"recipes": [...], "query": "chicken"},
    "mode": "replace"
  },
  "speech": "Found 20 chicken recipes.",
  "auto_close": false,
  "expects_response": true
}

## Example 3: Timer
User: "Set timer for 15 minutes"

1. Call create_timer(duration_seconds=900, label=null)
2. Tool returns: {"timer_id": "t1", "duration": 900}
3. Respond:
{
  "intent": "set_timer",
  "ui_action": {
    "component": "timer_display",
    "payload": {"timer": {...}},
    "mode": "overlay"
  },
  "speech": "Timer started.",
  "auto_close": true,
  "expects_response": false
}

## Example 4: Clarification
User: "Show me that recipe"

Context: No recent recipe mentioned

Respond:
{
  "intent": "clarification_required",
  "ui_action": {
    "component": "text_response",
    "payload": {"text": "Which recipe do you mean?"}
  },
  "speech": "Which recipe do you mean?",
  "auto_close": false,
  "expects_response": true
}

# TONE
- Confident, not apologetic
- Helpful, not servile
- Professional, not robotic
- Brief, not terse

# CRITICAL REMINDERS
1. ALWAYS call tools before mentioning data
2. ALWAYS return valid JSON with required fields
3. NEVER hallucinate recipe names, ingredients, or cook times
4. UI components render data — your job is to fetch it and decide what to show
5. Brevity is premium UX — say less, show more
"""
```

---

## 5. BACKEND IMPLEMENTATION

### File: `backend/app/routers/voice_live.py` (Enhanced)

```python
# Add to imports
from app.schemas.assistant_response import AssistantResponse, UIAction, IntentType, UIComponentType
from app.modules.function_registry import COOKING_ASSISTANT_TOOLS
from app.config.system_prompts import COOKING_ASSISTANT_SYSTEM_PROMPT
import uuid
import json

# Update GeminiLiveSession class

class GeminiLiveSession:
    def __init__(self, websocket: WebSocket, session_id: str, db: Session):
        # ... existing init ...
        self.conversation_history: List[Dict] = []

    async def _handle_gemini_response(self, response_data: dict):
        """Parse Gemini response and build structured AssistantResponse"""

        # Extract function calls
        if "function_calls" in response_data:
            for func_call in response_data["function_calls"]:
                tool_result = await self._execute_function(func_call)
                # Send tool result back to Gemini
                await self.gemini_session.send(tool_result)

        # Extract text/audio
        if "text" in response_data:
            text = response_data["text"]

            # Try to parse as JSON (if AI returned structured output)
            try:
                structured_response = json.loads(text)

                # Validate against AssistantResponse schema
                response = AssistantResponse(**structured_response)
                response.response_id = str(uuid.uuid4())

                # Send to frontend
                await self.websocket.send_json({
                    "type": "assistant_response",
                    "response": response.dict()
                })

            except (json.JSONDecodeError, ValidationError):
                # Fallback: treat as plain text
                await self.websocket.send_json({
                    "type": "transcript",
                    "text": text
                })

        # Forward audio if present
        if "audio" in response_data:
            await self.websocket.send_json({
                "type": "audio",
                "data": response_data["audio"],
                "mime_type": "audio/pcm",
                "sample_rate": 24000
            })

    async def _execute_function(self, func_call: dict) -> dict:
        """Execute function and return result"""
        func_name = func_call["name"]
        args = func_call["args"]

        try:
            if func_name == "search_recipes":
                result = search_recipes(
                    query=args["query"],
                    filters=args.get("filters", {}),
                    limit=args.get("limit", 10),
                    db=self.db
                )

            elif func_name == "get_recipe_by_id":
                result = get_recipe_by_id(
                    recipe_id=args["recipe_id"],
                    db=self.db
                )

            elif func_name == "create_timer":
                result = create_timer(
                    duration_seconds=args["duration_seconds"],
                    label=args.get("label")
                )

            # ... other functions ...

            return {
                "function_response": {
                    "name": func_name,
                    "response": {"success": True, "data": result}
                }
            }

        except Exception as e:
            logger.error(f"Function {func_name} failed: {e}")
            return {
                "function_response": {
                    "name": func_name,
                    "response": {"success": False, "error": str(e)}
                }
            }

# Update session initialization
async def _initialize_gemini_session(self):
    self.gemini_session = genai.live.connect(
        model="models/gemini-2.0-flash-exp",
        config={
            "generation_config": {
                "temperature": 0.7,
                "response_modalities": ["AUDIO", "TEXT"],
            },
            "system_instruction": COOKING_ASSISTANT_SYSTEM_PROMPT,
            "tools": [COOKING_ASSISTANT_TOOLS],
        }
    )
```

---

## 6. FRONTEND UI RENDERER

### File: `frontend/lib/features/chat/services/response_handler.dart`

```dart
import 'package:flutter/material.dart';
import '../schemas/assistant_response.dart';
import '../widgets/recipe_detail_view.dart';
import '../widgets/recipe_grid_view.dart';
import '../widgets/timer_display_view.dart';
import '../widgets/disambiguation_cards.dart';

class AssistantResponseHandler {
  final Function(Widget) onRenderComponent;
  final Function(String) onSpeak;
  final Function() onClose;

  AssistantResponseHandler({
    required this.onRenderComponent,
    required this.onSpeak,
    required this.onClose,
  });

  void handleResponse(AssistantResponse response) {
    // 1. Speak (if any)
    if (response.speech != null) {
      onSpeak(response.speech!);
    }

    // 2. Render UI
    if (response.uiAction != null) {
      final widget = _buildComponentFromAction(response.uiAction!);
      onRenderComponent(widget);
    }

    // 3. Auto-close
    if (response.autoClose) {
      Future.delayed(Duration(seconds: 2), () {
        onClose();
      });
    }
  }

  Widget _buildComponentFromAction(UIAction action) {
    switch (action.component) {
      case UIComponentType.recipeDetail:
        return RecipeDetailView(
          recipe: Recipe.fromJson(action.payload['recipe']),
          transition: action.transition,
        );

      case UIComponentType.recipeGrid:
        return RecipeGridView(
          recipes: (action.payload['recipes'] as List)
              .map((r) => Recipe.fromJson(r))
              .toList(),
          query: action.payload['query'],
        );

      case UIComponentType.timerDisplay:
        return TimerDisplayView(
          timer: CookingTimer.fromJson(action.payload['timer']),
          mode: action.mode,
        );

      case UIComponentType.disambiguationCards:
        return DisambiguationCards(
          options: action.payload['options'],
          question: action.payload['question'],
        );

      default:
        return TextResponseView(
          text: action.payload['text'] ?? 'Unknown response',
        );
    }
  }
}
```

---

## 7. CONVERSATION FLOW EXAMPLES

### Example Flow 1: Recipe Discovery

```
User: "What can I make with carrots and chickpeas?"

Backend:
1. Gemini calls search_recipes(query="carrots chickpeas")
2. DB returns 6 recipes
3. Gemini decides: 6 results → recipe_grid
4. Returns:
{
  "intent": "search_recipes",
  "ui_action": {
    "component": "recipe_grid",
    "payload": {"recipes": [...]},
  },
  "speech": "Found 6 recipes with carrots and chickpeas.",
  "auto_close": false
}

Frontend:
- Plays speech audio
- Renders RecipeGridView with 6 cards
- Assistant stays open (expects_response: true)

User: "Show me the Moroccan one"

Backend:
1. Gemini identifies "Moroccan" from context
2. Filters previous results or searches again
3. Calls get_recipe_by_id(recipe_id="...")
4. Returns:
{
  "intent": "show_recipe",
  "ui_action": {
    "component": "recipe_detail",
    "payload": {"recipe": {...}},
    "transition": "slide"
  },
  "speech": null,
  "auto_close": true
}

Frontend:
- Renders RecipeDetailView
- Assistant minimizes after 2s
```

---

### Example Flow 2: Cooking Mode

```
User: [Opens recipe for "Thieboudienne"]
User: "Start cooking mode"

Backend:
1. Gemini recognizes current recipe context
2. Returns:
{
  "intent": "start_cooking_mode",
  "ui_action": {
    "component": "cooking_mode",
    "payload": {
      "recipe": {...},
      "step": 1,
      "hands_free": true
    }
  },
  "speech": "Starting cooking mode. Step 1: Prepare the vegetables.",
  "auto_close": true
}

Frontend:
- Renders CookingModeView (full-screen, voice-first)
- Auto-reads steps aloud
- Listens for voice commands: "next", "repeat", "timer"

User: "Next"

Backend:
- Advances to step 2
- Auto-creates timer if step mentions cooking time

User: "Set timer for 10 minutes"

Backend:
1. Calls create_timer(600)
2. Returns overlay timer
3. Cooking mode stays active underneath
```

---

## 8. COMMON MISTAKES TO AVOID

### ❌ MISTAKE #1: LLM Renders UI via Text
```python
# WRONG
response = llm.complete("Show recipe for pasta")
# Returns: "Here's the recipe:\n\nIngredients:\n- 500g pasta..."
```

**Problem:** Breaks on mobile, no interactivity, formatting issues

**RIGHT:**
```python
response = {
  "ui_action": {"component": "recipe_detail", "payload": {...}}
}
```

---

### ❌ MISTAKE #2: No Tool Enforcement
```python
# WRONG - LLM can hallucinate
response = gemini.generate(user_input)
```

**RIGHT:**
```python
# Force tool usage for data queries
if intent_requires_data(user_input):
    response = gemini.generate(
        user_input,
        tools=COOKING_ASSISTANT_TOOLS,
        tool_choice="required"  # Must use tools
    )
```

---

### ❌ MISTAKE #3: No Conversation Context
```python
# WRONG - Every query is fresh
gemini.generate(user_input)
```

**RIGHT - Gemini Live manages context automatically:**
```python
# Context is preserved across turns
await gemini_session.send(user_input)
# Gemini remembers previous conversation
```

---

### ❌ MISTAKE #4: Verbose Responses
```json
{
  "speech": "I've found several delicious recipes that match your query. Let me display them for you in a grid format so you can easily browse through the options."
}
```

**RIGHT:**
```json
{
  "speech": "Found 8 recipes.",
  "ui_action": {"component": "recipe_grid", ...}
}
```

---

### ❌ MISTAKE #5: Manual JSON Parsing
```dart
// WRONG
final response = jsonDecode(text);
if (response['intent'] == 'show_recipe') {
  // Manual if-else hell
}
```

**RIGHT:**
```dart
// Type-safe schema validation
final response = AssistantResponse.fromJson(jsonData);
final widget = _buildComponentFromAction(response.uiAction);
```

---

## 9. ELITE FEATURES

### Feature 1: Proactive Timer Alerts
```dart
class TimerService {
  Stream<TimerAlert> get alerts {
    return _timers.where((t) => t.remaining == 60).map((t) =>
      TimerAlert(
        message: "${t.label} ending in 1 minute",
        action: AssistantAction.speak
      )
    );
  }
}

// In UI:
timerService.alerts.listen((alert) {
  geminiService.sendText(alert.message); // Proactive notification
});
```

---

### Feature 2: Smart Suggestions
```dart
class ContextualSuggestions {
  List<String> getSuggestions(AppState state) {
    if (state.currentRecipe != null) {
      return [
        "Start cooking mode",
        "Add to shopping list",
        "Show similar recipes",
        "Scale to 4 servings"
      ];
    } else if (state.searchResults?.isNotEmpty == true) {
      return [
        "Filter by difficulty",
        "Show only vegetarian",
        "Sort by cook time"
      ];
    }
    return ["Show popular recipes", "What's for dinner?"];
  }
}
```

---

### Feature 3: Cooking Mode with Auto-Timers
```python
# In system prompt
"""
When user starts cooking mode and encounters a step with cooking time:
1. Automatically create timer
2. Include in response

Example:
Step: "Simmer for 20 minutes, stirring occasionally."

Response:
{
  "intent": "cooking_mode_step",
  "ui_action": {
    "component": "cooking_mode",
    "payload": {
      "step": {...},
      "auto_timer": {"duration": 1200, "label": "Simmer"}
    }
  },
  "speech": "Simmering for 20 minutes. Timer started."
}
"""
```

---

### Feature 4: Visual Recipe Search
```python
# Add tool
VISUAL_SEARCH_TOOL = FunctionDeclaration(
    name="identify_dish_from_image",
    description="Identify dish from uploaded image and find similar recipes",
    parameters=Schema(
        type="object",
        properties={
            "image_base64": Schema(type="string"),
        },
        required=["image_base64"]
    )
)

# Implementation
async def identify_dish_from_image(image_base64: str, db: Session):
    # Use Gemini Vision API
    result = await gemini_vision.generate_content([
        {"mime_type": "image/jpeg", "data": base64.b64decode(image_base64)},
        "What dish is this? Provide name and key ingredients."
    ])

    dish_name = result.text

    # Search for similar recipes
    recipes = search_recipes(query=dish_name, limit=5, db=db)

    return {
        "identified_dish": dish_name,
        "similar_recipes": recipes
    }
```

---

### Feature 5: Ingredient Substitutions
```python
SUBSTITUTION_TOOL = FunctionDeclaration(
    name="suggest_substitution",
    description="Suggest ingredient substitutions based on user's inventory",
    parameters=Schema(
        type="object",
        properties={
            "missing_ingredient": Schema(type="string"),
            "recipe_id": Schema(type="string"),
        },
        required=["missing_ingredient", "recipe_id"]
    )
)

# Example usage:
User: "I don't have heavy cream"
Gemini: [In cooking mode, identifies recipe context]
→ suggest_substitution(missing_ingredient="heavy cream", recipe_id="current")
→ Returns: ["milk + butter", "coconut cream", "greek yogurt"]
→ Response: "Try milk + butter or coconut cream instead."
```

---

## 10. IMPLEMENTATION ROADMAP

### Phase 1: Core Architecture (Week 1)
- [x] Fix voice bugs (COMPLETED)
- [ ] Implement AssistantResponse schema
- [ ] Add structured output parsing in backend
- [ ] Build UI component router in frontend
- [ ] Test basic intent flow

### Phase 2: Tool Enforcement (Week 2)
- [ ] Enhance function_registry with all tools
- [ ] Implement tool result validation
- [ ] Add tool_choice enforcement for data queries
- [ ] Test tool calling flows

### Phase 3: System Prompt Refinement (Week 3)
- [ ] Deploy production system prompt
- [ ] A/B test response brevity
- [ ] Tune auto_close logic
- [ ] Optimize conversation context

### Phase 4: Elite Features (Week 4)
- [ ] Proactive timer alerts
- [ ] Contextual suggestions
- [ ] Visual search (optional)
- [ ] Smart substitutions (optional)

---

## SUMMARY

**#1 Rule:** LLM is a **decision engine**, not a text generator.

**Architecture:**
- Gemini Live API with function calling
- Structured JSON responses (AssistantResponse schema)
- Tool-first enforcement (no hallucination)
- UI component mapping (not text rendering)

**Key Decisions:**
1. Use Pydantic schemas for validation
2. Enforce tool usage via system prompt + tool_choice
3. Keep speech field brief or null
4. Let UI components render data beautifully
5. Context managed automatically by Gemini Live

**Success Metrics:**
- Zero hallucinated recipes
- < 3s response latency
- 80%+ queries result in UI rendering (not text)
- 90%+ user satisfaction with brevity
- Clear auto-close behavior

---

This is your production blueprint. Implement it step-by-step and you'll have a category-defining AI cooking assistant.
