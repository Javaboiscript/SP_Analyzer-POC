"""
Tools registry router exposing configured tools, parameter specifications, and analytical prompts.
"""

import json
import os
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api", tags=["Tools Registry"])

CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config", "tools.json")


def load_tools_config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        raise HTTPException(status_code=500, detail="Configuration file config/tools.json not found.")
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse config/tools.json: {str(e)}")


@router.get(
    "/tools",
    summary="Get Tool & Prompt Registry",
    description="Returns all registered analysis tools (Sales, PO, Indent), their required/optional parameters, default values, and available analytical prompts."
)
def get_tools() -> dict:
    return load_tools_config()
