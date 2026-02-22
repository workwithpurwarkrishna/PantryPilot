import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.config import Settings, get_settings
from app.models.schemas import AuthLoginRequest, AuthTokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=AuthTokenResponse)
def login(
    payload: AuthLoginRequest,
    settings: Settings = Depends(get_settings),
) -> AuthTokenResponse:
    if not settings.supabase_url or not settings.auth_api_key():
        raise HTTPException(status_code=500, detail="Supabase auth configuration is incomplete")

    try:
        response = httpx.post(
            f"{settings.supabase_url}/auth/v1/token?grant_type=password",
            headers={
                "apikey": settings.auth_api_key(),
                "Content-Type": "application/json",
            },
            json={"email": payload.email, "password": payload.password},
            timeout=15.0,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Supabase auth service unavailable") from exc

    if response.status_code != 200:
        detail = "Invalid email or password"
        try:
            error_payload = response.json()
            detail = error_payload.get("msg") or error_payload.get("error_description") or detail
        except Exception:
            pass
        raise HTTPException(status_code=401, detail=detail)

    data = response.json()
    return AuthTokenResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        token_type=data.get("token_type", "bearer"),
        expires_in=int(data.get("expires_in", 3600)),
    )
