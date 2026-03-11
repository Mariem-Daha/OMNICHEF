"""AI Chat API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.orm import Session

from ..database import get_db
from ..services.ai_service import get_ai_service, AIService
from ..services.auth_service import get_current_user_optional
from ..models.user import User

router = APIRouter()


class ChatMessage(BaseModel):
    """Single chat message."""
    content: str
    is_user: bool


class ChatRequest(BaseModel):
    """Request body for chat endpoint."""
    message: str
    conversation_history: Optional[list[ChatMessage]] = None


class ChatResponse(BaseModel):
    """Response from chat endpoint."""
    response: str
    success: bool


@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    ai_service: AIService = Depends(get_ai_service),
    current_user: User | None = Depends(get_current_user_optional),
):
    """
    Send a message to the AI cooking assistant and get a response.
    
    - **message**: The user's message to the AI
    - **conversation_history**: Optional previous messages for context
    """
    try:
        # Convert conversation history to dict format
        history = None
        if request.conversation_history:
            history = [
                {"content": msg.content, "is_user": msg.is_user}
                for msg in request.conversation_history
            ]
        
        # Build user health context from the authenticated user (if any)
        user_context = None
        if current_user:
            user_context = {
                "health_filters": current_user.health_filters or [],
                "allergies": current_user.allergies or [],
                "disliked_ingredients": current_user.disliked_ingredients or [],
                "taste_preferences": current_user.taste_preferences or [],
                "cooking_skill": current_user.cooking_skill or "Intermediate",
            }

        # Generate response
        response = await ai_service.chat(request.message, history, user_context=user_context)
        
        return ChatResponse(
            response=response,
            success=True
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate response: {str(e)}"
        )


@router.get("/health")
async def chat_health(ai_service: AIService = Depends(get_ai_service)):
    """Check if the AI service is available."""
    return {
        "status": "healthy" if ai_service.client else "degraded",
        "model_available": ai_service.client is not None,
    }


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    """WebSocket endpoint for real-time AI chat."""
    await websocket.accept()
    ai_service = get_ai_service()
    
    try:
        while True:
            # Wait for message
            data = await websocket.receive_text()
            
            # Simple validation: if JSON string, parse it. If plain text, use as is.
            import json
            message = data
            try:
                msg_json = json.loads(data)
                if isinstance(msg_json, dict) and "message" in msg_json:
                    message = msg_json["message"]
            except json.JSONDecodeError:
                pass
            
            if not message:
                continue

            # Stream response
            async for chunk in ai_service.chat_stream(message, db):
                await websocket.send_json(chunk)
                
            # Signal completion of this turn
            await websocket.send_json({"type": "done"})
                
    except WebSocketDisconnect:
        # Handle disconnect gracefully
        pass
    except Exception as e:
        print(f"WebSocket error: {e}")
        try:
            await websocket.close()
        except:
            pass
