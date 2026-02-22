from fastapi import APIRouter, Depends, Header, HTTPException

from app.dependencies import AuthUser, get_current_user
from app.models.schemas import ChatMessageRequest, ChatResponse
from app.services.ai_service import AIService
from app.services.db_service import DBService

router = APIRouter(prefix="/chat", tags=["chat"])


def get_ai() -> AIService:
    return AIService()


def get_user_db(user: AuthUser = Depends(get_current_user)) -> DBService:
    return DBService(access_token=user.access_token)


@router.post("/message", response_model=ChatResponse)
def post_message(
    payload: ChatMessageRequest,
    user: AuthUser = Depends(get_current_user),
    ai: AIService = Depends(get_ai),
    db: DBService = Depends(get_user_db),
    x_custom_api_key: str | None = Header(default=None),
) -> ChatResponse:
    if payload.provider != "groq":
        raise HTTPException(status_code=400, detail="Unsupported provider")

    user_text = payload.text
    if not user_text and not payload.audio_base64:
        raise HTTPException(status_code=400, detail="Provide either text or audio_base64")

    try:
        db.ensure_profile(user.id)
        pantry_items = db.get_pantry(user.id)

        if not user_text and payload.audio_base64:
            user_text = ai.transcribe_audio(payload.audio_base64, x_custom_api_key)

        return ai.generate_recipe_cards(user_text or "", pantry_items, x_custom_api_key)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
