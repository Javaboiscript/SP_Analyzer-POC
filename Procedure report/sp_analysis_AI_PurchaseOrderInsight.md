# Stored Procedure Analysis: `Purchase.AI_PurchaseOrderInsight`

---

## 1. Executive Summary

| Property | Value |
|---|---|
| **Procedure Name** | `[Purchase].[AI_PurchaseOrderInsight]` |
| **Database** | `SpectrumERP` |
| **Object ID** | `384926501` |
| **Author / Date** | Alok (15/10/2026) |
| **Lines of Code** | 1,025 lines |
| **Execution Time** | **~350 ms** (measured against live SQL Server) |
| **Total Result Sets Returned** | **10 Fixed-Shape Result Sets** (Sets 0 through 9) |
| **Target Tool** | **PO Analyzer** (`po_analyzer` in `tools.json`) |

`Purchase.AI_PurchaseOrderInsight` is specifically designed for AI consumption. It reconstructs the **complete lifecycle of a single Purchase Order** across 10 structured tables—from header and item pricing, to gate arrival, quality inspection, GRN acceptance/rejection, purchase invoice booking, item reconciliation, and executive summary flags.

---

## 2. Input Parameters

The stored procedure accepts three flexible parameters:

| Parameter | Type | Required? | Default | Description |
|---|---|---|---|---|
| `@PONo` | `int` | Optional* | `NULL` | Internal primary key (`Purchase.POMain.PONo`). Takes precedence. |
| `@PONoYearly` | `varchar(50)` | Optional* | `NULL` | Business document number visible to users (e.g. `'0090/22-23'`). |
| `@CompanyNo` | `tinyint` | Optional | `NULL` | Company ID filter (only needed if `@PONoYearly` is shared across companies). |

> *\*Note: Either `@PONo` OR `@PONoYearly` must be supplied. If neither matches, all 10 result sets are still returned with their exact schemas but 0 rows, with status `PO_NOT_FOUND` in Set 0.*

---

## 3. The 10 Result Sets (Table Breakdown)

Every call returns exactly **10 fixed-shape result sets** in deterministic order:

| Set # | Table Name | Grain | Column Count | Description & Key Insights |
|:---:|---|---|:---:|---|
| **0** | **Metadata** | 1 row per meta item | 7 | Describes execution status (`OK`, `PO_NOT_FOUND`, `AMBIGUOUS_PO`), parameters, business rules, and schemas of sets 1–9. |
| **1** | **POHeader** | 1 row per PO | 40 | Vendor name/location, department, PO date, currency & exchange rate, net amount, validity status (`Active`/`Expired`), amendment history, authorization, and age in days. |
| **2** | **POItem** | 1 row per PO line | 31 | Ordered items, item code, technical grade, UOM, HSN, ordered quantity, rate, discount, net amount, delivery schedule dates (`MinScheduleDate`, `MaxScheduleDate`), and tolerance. |
| **3** | **POItemTax** | 1 row per item tax line | 15 | Item-level tax and discount breakdown (CGST, SGST, IGST, Trade Discount, etc.) with rate and calculation effect (`Add`/`Deduct`). |
| **4** | **POTaxSummary** | 1 row per PO tax head | 15 | Order-level tax summary grouped by GST sequence (`Before GST`, `GST`, `After GST`). |
| **5** | **GateEntry** | 1 row per gate entry | 26 | Physical material arrivals recorded at the factory gate (Challan Qty, Vehicle No, Transporter, Gate Entry Date, Days Gate-to-Receipt, Pending at Gate Qty). |
| **6** | **Receipt** | 1 row per GRN/SIN line | 29 | Material receipt inspection (GRN, Sub-contract BOQ GRN, Discrete RM Store Inward). Records Challan Qty, Physical Received Qty, Accepted Qty, and **Rejected Qty**. |
| **7** | **PurchaseBill** | 1 row per invoice line | 22 | Accounts Payable booking. Billed Qty, Bill Net Amount, Bill Date, Payment Mode, and **Outstanding Payable Amount**. |
| **8** | **ItemQtySummary** | 1 row per PO line | 40 | **Complete line-level quantity reconciliation**: PO Qty → Gate Entry Qty → GRN Challan → Received → Accepted → Rejected → Billed → Pending Billing → Cancelled → **POBalanceQty**, Schedule Delay Days, and **Pre-computed `InsightFlags`**. |
| **9** | **POSummary** | 1 row per PO | 44 | **High-level executive roll-up**: Overall Status (`COMPLETED`, `PARTIALLY_RECEIVED`, `NOT_STARTED`, `CANCELLED`), Value Fulfillment %, Days Lead Time, Total Rejection Qty, Total Outstanding, and **Executive `InsightFlags`**. |

---

## 4. Built-in `InsightFlags` (Domain Intelligence)

The stored procedure computes enterprise risk flags automatically:

### Line-Level Flags (Result Set 8):
* `OVERDUE`: Item has delivery schedule dates that are past due.
* `PENDING_GRN_AT_GATE`: Material is physically waiting at the gate but hasn't been inspected/receipted into inventory.
* `REJECTION`: Quality inspection rejected a portion of the delivery.
* `PENDING_BILLING`: Material is inspected and accepted, but vendor bill has not been booked by Finance.
* `EXCESS_RECEIPT`: Supplier sent more quantity than the approved purchase order.
* `CANCELLED_OR_SHORT_CLOSED`: Line was cancelled or short-closed by procurement.
* `FULLY_RECEIVED`: Balance is zero; order line is fulfilled.

### PO-Level Flags (Result Set 9):
* `VALIDITY_EXPIRED_WITH_BALANCE`: PO validity date expired, but unfulfilled open balance remains.
* `HAS_OVERDUE_ITEMS`: One or more items are delayed.
* `HAS_REJECTION`: Quality rejections exist.
* `PAYMENT_OUTSTANDING`: Financial payable balance is pending against booked bills.
* `AMENDED`: PO has undergone one or more formal amendments.

---

## 5. How Our Backend Handles These 10 Tables

### 1. Multi-ResultSet Capture (`db/sql_client.py`)
Our `sql_client.execute_query_multi_resultset` uses `pyodbc.cursor.nextset()` in an iterative loop. It automatically reads all 10 tables, records their column names and rows, and measures total execution time (**~350 ms** on SQL Server 2022).

### 2. Intelligent Table Naming & Contextualization
Currently, tables are named `ResultSet_1`, `ResultSet_2`, etc. For `AI_PurchaseOrderInsight`, we can map the 10 result sets to their semantic names:
* Table 0: `Metadata`
* Table 1: `POHeader`
* Table 2: `POItem`
* Table 3: `POItemTax`
* Table 4: `POTaxSummary`
* Table 5: `GateEntry`
* Table 6: `Receipts_GRN`
* Table 7: `PurchaseBills`
* Table 8: `ItemQtySummary`
* Table 9: `POSummary`

### 3. Token-Efficient Formatting for Gemini (`ai/gemini_client.py`)
Because a single PO touches at most a few items, gate entries, and receipts:
* Total rows across all 10 tables typically range between **10 and 50 rows**.
* The entire 10-table payload is compact (**~2,500–4,500 tokens**), fitting into Gemini 2.5 Flash's 1,000,000 token context window.
* In our prompt construction, Result Sets 8 (`ItemQtySummary`) and 9 (`POSummary`) provide instant, pre-computed mathematical truth, while Sets 1, 2, 5, 6, and 7 provide the granular supporting evidence for the reasoning model.

---

## 6. Recommended AI Prompts for `po_analyzer`

With these 10 tables, we can configure 4 specialized analytical prompts in `config/tools.json`:

1. **`po_lifecycle_audit` (Comprehensive PO Health & Lifecycle Audit)**:
   * Assesses overall completion status, open balances, vendor compliance, and key bottleneck areas.
2. **`vendor_delivery_lead_time` (Supplier Delivery Performance & Delays)**:
   * Analyzes `MinScheduleDate`, `GateEntryDate`, `DaysGateToReceipt`, and `ScheduleDelayDays` to evaluate supplier punctuality and lead time variance.
3. **`quality_rejection_audit` (Quality & Inspection Rejections)**:
   * Focuses on `ChallanQty`, `ReceivedQty`, `AcceptedQty`, and `RejectedQty` across GRN lines to identify defective batches, return risks, and supplier quality issues.
4. **`financial_billing_reconciliation` (Three-Way Match & Pending Billing Audit)**:
   * Audits the 3-way match: PO Item Value vs. GRN Accepted Value vs. Purchase Bill Amount, flagging unbilled inventory (`PendingBillingQty`) and outstanding payables.
