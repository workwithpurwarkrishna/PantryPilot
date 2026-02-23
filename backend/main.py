from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers.auth import router as auth_router
from app.routers.chat import router as chat_router
from app.routers.history import router as history_router
from app.routers.ingredients import router as ingredients_router
from app.routers.pantry import router as pantry_router

app = FastAPI(title="PantryPilot API", version="0.1.0")
settings = get_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(pantry_router)
app.include_router(chat_router)
app.include_router(auth_router)
app.include_router(ingredients_router)
app.include_router(history_router)
