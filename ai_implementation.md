# 🤖 Cuisinee AI Implementation Plan

## Overview

| Phase | What | Goal |
|-------|------|------|
| **Phase 1** | Voice Assistant | OpenAI Realtime API + database recipes + health personalization |
| **Phase 2** | AI Sous Chef | Silent companion with wake word, timers, proactive cooking help |

---

# Phase 1: Voice Assistant (MVP)

> **Goal:** A fully working voice AI that can search recipes, personalize for health, and have natural conversation.

## What It Does

- User talks to AI, AI talks back (natural audio conversation)
- AI searches recipes from YOUR database only (never invents)
- AI personalizes recipes for health conditions
- AI can save recipes to favorites
- Works like ChatGPT voice mode

## Technology

| Component | Solution |
|-----------|----------|
| Voice Conversation | OpenAI GPT-4o-mini Realtime API (WebSocket) |
| Database Search | Function calling → your backend API |
| Health Personalization | Function calling + personalization logic |

## How It Works

```
User speaks → OpenAI Realtime API → AI responds with audio
                    ↓
              Function calls (as needed)
                    ↓
              Your backend (recipes, save, personalize)
```

## AI Capabilities

| User Says | AI Does |
|-----------|---------|
| "Find me a chicken recipe" | Searches database, returns options |
| "I'm diabetic, modify this" | Removes sugar, suggests alternatives |
| "Save this recipe" | Adds to user favorites |
| "What's in Thieboudienne?" | Gets recipe details from database |
| "I don't eat sugar" | Removes all sugar from recipe |

## Core Rules

1. **Database only** - AI never invents recipes
2. **Health aware** - Always offers to personalize when user mentions conditions
3. **Culturally appropriate** - Knows Mauritanian/MENA cuisine

## Cost Estimate

~$38/month for 100 voice sessions + 1000 text messages

---

# Phase 2: AI Sous Chef (Advanced)

> **Goal:** A silent kitchen companion that listens for its name, manages timers, and helps proactively during cooking.

## Concept

The AI Sous Chef is like a real sous chef in your kitchen:
- **Silent by default** - doesn't interrupt
- **Always ready** - activated by wake word
- **Manages timers** - announces when done
- **Proactive** - suggests next steps at the right moment

## Wake Word Activation

| Wake Word | What Happens |
|-----------|--------------|
| "Hey Chef" | AI starts listening |
| "Hey Sous Chef" | Same |
| "Cuisinee" | Same |

After wake word, user speaks naturally and AI responds.

## Features

### 1. Timer Management

```
User: "Hey Chef, set a timer for 10 minutes for the rice"
AI: "Timer set for 10 minutes."

[10 minutes later]
AI: "Your rice timer is done! Ready for the next step?"
```

### 2. Step-by-Step Cooking

```
User: "Hey Chef, start cooking Thieboudienne"
AI: "Starting Thieboudienne! Step 1: Clean and season the fish..."

User: "Next"
AI: [reads next step]

User: "Repeat"
AI: [repeats current step]
```

### 3. Hands-Free Commands

| Command | Action |
|---------|--------|
| "Next step" | Move to next step |
| "Go back" | Previous step |
| "Repeat" | Re-read current step |
| "Timer X minutes" | Set cooking timer |
| "What step am I on?" | Current position |
| "Pause" | Pause cooking mode |

### 4. Proactive Assistance

AI speaks on its own when:
- Timer finishes
- Long pause at a step (offers help)
- Before time-sensitive steps (reminds user)

## Cost Optimization

Many commands are handled **locally** (free):

| Type | Handler | Cost |
|------|---------|------|
| "Next step" | Local | FREE |
| "Repeat" | Local | FREE |
| "Timer 5 min" | Local | FREE |
| Timer announcements | Local TTS | FREE |
| "Help, my sauce is burning!" | API | Paid |
| "Substitute for tamarind?" | API | Paid |

**Estimated savings:** ~50% → **~$18/month**

## Wake Word Technology

| Option | Type | Cost |
|--------|------|------|
| Porcupine (Picovoice) | Edge AI | Free personal, $6K/yr commercial |
| Simple keyword detection | Rule-based | Free |
| Always-on WebSocket | API | Expensive (not recommended) |

---

# Implementation Timeline

## Phase 1: Voice Assistant (2-3 weeks)

### Week 1: Backend
- [ ] Create OpenAI service with function calling
- [ ] Implement 4 functions (search, details, personalize, save)
- [ ] Add Realtime API session endpoint
- [ ] Recipe personalization logic

### Week 2: Frontend
- [ ] Voice mode screen with WebSocket connection
- [ ] Listening/speaking UI states
- [ ] Handle function call responses
- [ ] Test end-to-end

### Week 3: Polish
- [ ] Error handling
- [ ] Edge cases
- [ ] User testing

## Phase 2: Sous Chef Mode (2-3 weeks)

### Week 1: Local Commands
- [ ] Wake word detection ("Hey Chef")
- [ ] Local command handler (next, repeat, timer)
- [ ] Platform TTS for responses
- [ ] Timer management

### Week 2: Cooking Mode
- [ ] Step-by-step cooking flow
- [ ] Proactive timer announcements
- [ ] Recipe context management
- [ ] Hybrid: local + API routing

### Week 3: Polish
- [ ] Fine-tune wake word sensitivity
- [ ] Test in noisy kitchen environment
- [ ] Battery/performance optimization

---

# Setup Required

## Environment

```env
# backend/.env
OPENAI_API_KEY=sk-...
```

## Dependencies

**Backend:**
- `openai>=1.0.0`

**Frontend (Phase 2):**
- Wake word detection package
- Platform TTS support

---

# Summary

| | Phase 1 | Phase 2 |
|-|---------|---------|
| **Type** | Active voice assistant | Passive sous chef |
| **Activation** | User opens voice mode | Wake word "Hey Chef" |
| **Primary Use** | Recipe search, Q&A | Step-by-step cooking |
| **Cost/month** | ~$38 | ~$18 (with optimization) |
| **Complexity** | Moderate | Higher |
| **Timeline** | 2-3 weeks | 2-3 weeks |

**Start with Phase 1** → Get it working perfectly → **Then add Phase 2** features

Ready to begin! 🚀
