from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from anthropic import Anthropic
import json
import logging

log = logging.getLogger(__name__)

router = APIRouter()
client = Anthropic()


def parse_json_response(text: str) -> dict:
    """Parse JSON from Claude response, stripping markdown fences or surrounding text."""
    text = text.strip()
    # Strip markdown code fences
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else text[3:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()
    # Try direct parse first
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Try extracting JSON object from surrounding text
    start = text.find("{")
    end = text.rfind("}") + 1
    if start != -1 and end > start:
        return json.loads(text[start:end])
    raise ValueError(f"Could not parse JSON from response: {text[:200]}")

ROUTE_SYSTEM_PROMPT = """You are an expert AI development tool advisor. Given a task description,
determine the best tool: "Claude CLI", "Codex CLI", or "Cursor".

Rules:
- Claude CLI: multi-file refactoring, architecture, codebase understanding, complex new features,
  long context tasks, writing/analysis, agentic multi-step execution
- Codex CLI: quick isolated scripts, single functions, boilerplate generation, token-efficient
  simple tasks, fast one-off code
- Cursor: editing inside an existing file with visual context, small targeted fixes,
  autocomplete-driven iteration, anything where seeing the diff in real-time matters

Respond ONLY with valid JSON, no markdown:
{"tool": "Claude CLI", "reasoning": "one sentence explanation", "confidence": 0.85}"""

FORGE_SYSTEM_PROMPTS = {
    "Claude CLI": """You generate optimized prompts for Claude CLI (claude command in terminal).
Claude CLI loves: rich context, explicit file paths, multi-step instructions, output format specs.
Style: verbose, structured, include constraints and edge cases. Use markdown headings if multi-part.
Respond ONLY with valid JSON, no markdown:
{"optimized_prompt": "...", "platform": "Claude CLI", "tips": ["tip1", "tip2"]}""",

    "Codex CLI": """You generate optimized prompts for OpenAI Codex CLI (codex command in terminal).
Codex CLI loves: short, precise, unambiguous single-task instructions. One thing at a time.
Style: direct, minimal, no fluff. Like a precise technical spec in 1-3 sentences.
Respond ONLY with valid JSON, no markdown:
{"optimized_prompt": "...", "platform": "Codex CLI", "tips": ["tip1", "tip2"]}""",

    "Cursor": """You generate optimized prompts for Cursor IDE chat/composer.
Cursor loves: file-scoped instructions, "In FileName.swift, change X to Y. Keep Z unchanged."
Style: surgical, reference specific files/functions, describe the diff not the goal.
Respond ONLY with valid JSON, no markdown:
{"optimized_prompt": "...", "platform": "Cursor", "tips": ["tip1", "tip2"]}"""
}


class ForgeRequest(BaseModel):
    description: str
    platform: str | None = None


@router.post("/route-task")
async def route_task(req: ForgeRequest):
    try:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=300,
            system=ROUTE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": req.description}]
        )
        return parse_json_response(response.content[0].text)
    except Exception as e:
        log.exception("route-task failed")
        return JSONResponse(
            status_code=502,
            content={"error": str(e), "tool": "Claude CLI", "reasoning": "Fallback due to error", "confidence": 0.5}
        )


@router.post("/forge-prompt")
async def forge_prompt(req: ForgeRequest):
    platform = req.platform or "Claude CLI"
    system = FORGE_SYSTEM_PROMPTS.get(platform, FORGE_SYSTEM_PROMPTS["Claude CLI"])

    try:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=800,
            system=system,
            messages=[{"role": "user", "content": req.description}]
        )
        return parse_json_response(response.content[0].text)
    except Exception as e:
        log.exception("forge-prompt failed")
        return JSONResponse(
            status_code=502,
            content={"error": str(e), "optimized_prompt": "", "platform": platform, "tips": []}
        )
