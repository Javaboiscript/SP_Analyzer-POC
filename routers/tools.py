"""
Tools registry router exposing configured tools, parameter specifications, and analytical prompts.
"""

import json
import os
from fastapi import APIRouter, HTTPException

from db.sql_client import sql_client

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
    description="Returns all registered analysis tools, their parameters, default values, and available analytical prompts."
)
def get_tools() -> dict:
    return load_tools_config()


@router.get(
    "/companies",
    summary="Get List of Active Companies",
    description="Returns active companies from masterdata.mCompanyMaster for parameter dropdowns."
)
def get_companies() -> dict:
    try:
        query = (
            "SELECT CompanyNo, CompanyName, CompanyCode "
            "FROM masterdata.mCompanyMaster "
            "WHERE IsInActive = 0 "
            "ORDER BY CompanyNo"
        )
        tables, _ = sql_client.execute_query_multi_resultset(query, [])
        companies = []
        if tables and tables[0].get("rows"):
            for row in tables[0]["rows"]:
                comp_no = row[0]
                comp_name = row[1] or f"Company #{comp_no}"
                comp_code = row[2] or ""
                label = f"{comp_name} (#{comp_no})"
                if comp_code:
                    label += f" [{comp_code}]"
                companies.append({
                    "value": comp_no,
                    "label": label,
                    "name": comp_name,
                    "code": comp_code
                })
        return {"companies": companies}
    except Exception as e:
        # Fallback to known active companies if table query encounters issues
        return {
            "companies": [
                {"value": 4, "label": "Force Intellect Pvt Ltd. (#4) [CM0002]", "name": "Force Intellect Pvt Ltd.", "code": "CM0002"},
                {"value": 2, "label": "Demo company (#2) [CM0001]", "name": "Demo company", "code": "CM0001"},
                {"value": 5, "label": "EPC FIPL Pvt. Ltd. (#5) [CM0003]", "name": "EPC FIPL Pvt. Ltd.", "code": "CM0003"},
                {"value": 6, "label": "Trading FIPL Pvt. Ltd. (#6) [CM0004]", "name": "Trading FIPL Pvt. Ltd.", "code": "CM0004"},
                {"value": 7, "label": "General FIPL Pvt. Ltd. (#7) [CM0005]", "name": "General FIPL Pvt. Ltd.", "code": "CM0005"}
            ],
            "warning": str(e)
        }

