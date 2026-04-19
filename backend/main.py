"""AXIS Forge API — AI-powered platform routing and prompt generation."""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from forge_router import router as forge_router

app = FastAPI(
    title="AXIS Forge API",
    version="1.0.0",
    description="AI-powered platform routing (Claude CLI / Codex CLI / Cursor) and optimized prompt generation.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(forge_router)


@app.get("/")
async def root():
    return {"status": "ok", "service": "AXIS Forge API"}


@app.get("/health")
async def health():
    return {"status": "healthy"}
