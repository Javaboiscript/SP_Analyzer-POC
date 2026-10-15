# 🔬 AI-Powered Stored Procedure Analyzer (Backend POC)

A configuration-driven Python (FastAPI) backend service that executes Microsoft SQL Server stored procedures (including multi-resultset procedures like `[Finance].[SalesRegisterReport]`), captures the structured data, and uses **Google Gemini** to produce strategic analysis, anomaly detection, and executive summaries.

---

## 🚀 Features

* **SP-Agnostic & Metadata-Driven**: All tools, parameters, default values, SQL templates, and AI prompts are defined in [`config/tools.json`](file:///g:/AITests/Analyzer_POC/config/tools.json). Adding a new tool or prompt requires zero Python code changes.
* **SQL Server Multi-ResultSet Capture**: Uses `pyodbc` with **ODBC Driver 18 for SQL Server** to capture all result sets (`cursor.nextset()`) and execution timing.
* **SQL Templates per Prompt**: Each prompt can run its own targeted parameterized query template (e.g. `@InvoiceType = 1` for Tax Invoices vs `@InvoiceType = 2` for Returns).
* **Token & Data Safety**: Automatically caps large result sets at 500 rows and computes column-level aggregate totals (SUM, AVG, MIN, MAX) for complete analytical fidelity without token blowouts.
* **Structured AI Outputs**: Enforces strict Pydantic JSON schemas on Gemini (`gemini-2.5-flash`) via the modern `google-genai` SDK (`response_mime_type="application/json"`).
* **Built-in Swagger UI**: Test all endpoints interactively at `http://localhost:8000/docs`.

---

## 🛠️ Quick Start

### 1. Install Dependencies

Ensure Python 3.11+ is installed, then run:

```powershell
pip install -r requirements.txt
```

### 2. Configure Environment (`.env`)

Edit your [`.env`](file:///g:/AITests/Analyzer_POC/.env) file with your database credentials and Gemini API key:

```env
# SQL Server
SQL_SERVER=your_sql_server_host
SQL_DATABASE=your_database_name
SQL_USER=your_sql_user
SQL_PASSWORD=your_sql_password
SQL_PORT=1433
SQL_DRIVER=ODBC Driver 18 for SQL Server
SQL_TRUST_CERT=yes
SQL_TIMEOUT=30

# Google Gemini API
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.5-flash

# Application
PORT=8000
MAX_PROMPT_ROWS=500
```

### 3. Run the Backend Server

```powershell
python main.py
```
*(Or run `uvicorn main.py:app --reload --port 8000`)*

---

## 🧪 Testing with Swagger UI

1. Open your browser to **`http://localhost:8000/docs`** (or `http://localhost:8000`).
2. **Verify Database Connection**:
   * Expand `GET /api/health` -> Click **"Try it out"** -> **"Execute"**.
   * Confirm `"database_connected": true`.
3. **Inspect Registered Tools**:
   * Expand `GET /api/tools` -> Click **"Try it out"** -> **"Execute"**.
   * See all tools and prompts configured in `tools.json`.
4. **Execute Analysis**:
   * Expand `POST /api/analyze` -> Click **"Try it out"**.
   * The sample request is pre-filled:
     ```json
     {
       "toolId": "sales_analyzer",
       "promptId": "tax_invoice_gst_audit",
       "params": {
         "CompanyNo": 1,
         "FromDate": "2024-01-01",
         "ToDate": "2024-03-31",
         "CustomerLocationNo": 0,
         "InvoiceType": 1,
         "TaxBookNo": 0
       }
     }
     ```
   * Click **"Execute"**.
   * Review the structured AI insights (`executive_summary`, `key_metrics`, `findings`, `recommendations`) and raw SQL tables returned.

---

## 📁 Project Structure

```
Analyzer_POC/
├── .env                      # Database credentials & Gemini API key (ignored by git)
├── .env.example              # Environment variables template
├── requirements.txt          # Python dependencies
├── main.py                   # FastAPI app entry point & Swagger UI config
├── README.md                 # Documentation & setup guide
│
├── config/
│   └── tools.json            # Dynamic Tool, Parameter & Prompt Registry
│
├── models/
│   └── schemas.py            # Pydantic v2 Request, Response & AI Schemas
│
├── db/
│   └── sql_client.py         # pyodbc connection, query execution & multi-resultsets
│
├── ai/
│   └── gemini_client.py      # Table serialization, prompt construction & Gemini SDK
│
└── routers/
    ├── health.py             # GET /api/health (DB connectivity check)
    ├── tools.py              # GET /api/tools (Returns tools registry)
    └── analyze.py            # POST /api/analyze (Orchestrates SP -> AI)
```
