"""
Main entry point for the AI-Powered Stored Procedure Analyzer API.
Initializes FastAPI, registers CORS and routers, and configures Swagger UI at /docs.
"""

import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

from routers.health import router as health_router
from routers.tools import router as tools_router
from routers.analyze import router as analyze_router

load_dotenv()

app = FastAPI(
    title="AI-Powered Stored Procedure Analyzer",
    description="""
### 🔬 Proof of Concept: Multi-Tool Enterprise SQL Analyzer

Execute audited Microsoft SQL Server stored procedures (such as `[Finance].[SalesRegisterReport]`),
capture multi-table result sets, and generate structured executive AI analysis powered by **Google Gemini**.

---
* **Interactive Testing**: Click **"Try it out"** on `POST /api/analyze` below to run an analysis.
* **Connectivity Verification**: Use `GET /api/health` to confirm your SQL Server and ODBC Driver 18 connection.
* **Tool Registry**: Use `GET /api/tools` to view all available tools, parameters, and analytical prompts.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(health_router)
app.include_router(tools_router)
app.include_router(analyze_router)

# Static files & Web UI
public_dir = os.path.join(os.path.dirname(__file__), "public")
if os.path.exists(public_dir):
    app.mount("/static", StaticFiles(directory=public_dir), name="static")


@app.get("/", include_in_schema=False)
def root():
    """Serve Neo-Brutalist frontend UI or fallback to Swagger."""
    index_file = os.path.join(public_dir, "index.html")
    if os.path.exists(index_file):
        return FileResponse(index_file)
    return RedirectResponse(url="/docs")


@app.get("/styles.css", include_in_schema=False)
def get_styles():
    return FileResponse(os.path.join(public_dir, "styles.css"), media_type="text/css")


@app.get("/app.js", include_in_schema=False)
def get_app_js():
    return FileResponse(os.path.join(public_dir, "app.js"), media_type="application/javascript")


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)

