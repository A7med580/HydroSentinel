# HydroSentinel — Project Description & Changelog

## What Is HydroSentinel?

HydroSentinel is an industrial water chemistry monitoring application built with Flutter. It ingests Excel-based lab reports from cooling tower and reverse osmosis (RO) systems, calculates water quality indices (LSI, RSI, PSI, Larson-Skold, CoC), performs multi-factor risk assessment (scaling, corrosion, fouling), and presents actionable alerts with chemical reasoning to plant operators.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| State Management | Riverpod (`NotifierProvider`, `FutureProvider`, `StreamProvider`, `Provider.family`) |
| Backend | Supabase (Auth, PostgreSQL, Storage, Edge Functions) |
| Auth | Supabase Auth — email/password + Google OAuth |
| Database Tables | `factories`, `reports` (V1 legacy), `measurements_v2` (V2 active), `otp_verifications`, `risk_acceptance_log` |
| Storage | Supabase Storage bucket `factories` — path: `user_{emailPrefix}/{factoryName}/{file.xlsx}` |
| Charts | `fl_chart` |
| Excel Parsing | `excel` package + custom `UniversalExcelParser` pipeline |

---

## Core Architecture

```
Excel File → StorageService → UniversalExcelParser
  ├─ ExcelNormalizer (header scan + synonym matching)
  ├─ ExcelValidator (pH required, type checks)
  └─ _mapToDomain → CoolingTowerData + ROData

CoolingTowerData → CalculationEngine
  ├─ calculateIndices() → LSI, RSI, PSI, S&D, Larson-Skold, CoC
  ├─ assessRisk() → Scaling (0-100), Corrosion (0-100), Fouling (0-100)
  ├─ assessRO() → Oxidation Risk, Silica Scaling, Membrane Life
  ├─ calculateHealth() → Overall Score (0-100) + Status
  └─ generateRecommendations() → Alerts with WHY explanations

measurements_v2 → aggregatedDataProvider
  ├─ Daily-first calculation (score per day, then average)
  └─ UI: Dashboard / Trends / Alerts
```

---

## App Screens (7-Tab Navigation)

1. **Dashboard** — Health score circle, risk KPI grid, calculated indices, active alerts
2. **Factories** — Factory list with sync from Supabase Storage, per-factory sub-navigation
3. **Trends** — Line charts for health (black), scaling (green), corrosion (yellow) over time
4. **Chemistry** — Parameter display (intelligence/indices screen)
5. **Alerts** — Real-time recommendations with WHY explanations and action steps
6. **Reports** — Report listing
7. **Profile** — User profile and settings

### Factory Sub-Navigation (6 tabs)
Dashboard, Trends, Alerts, Intelligent (Indices), Reports, Analytics

---

## Excel File Contract

### Required Columns (case-insensitive, partial match)

| Parameter | Accepted Headers |
|---|---|
| pH | ph, ph value, p.h. |
| Alkalinity | alkalinity, total alkalinity, m-alk, alk |
| Conductivity | conductivity, cond, ec, electrical conductivity |
| Hardness | hardness, total hardness, th, calcium hardness |
| Chloride | chloride, cl, cl-, chlorides |
| Zinc | zinc, zn, zn2+ |
| Iron | iron, fe, total iron, fe2+, fe3+ |
| Phosphate | phosphate, po4, ortho phosphate, phosphates |
| Date | date, report date, sampling date |

### Optional Columns (RO)
| Free Chlorine | free chlorine, f-cl, free cl2 |
| Silica | silica, sio2, reactive silica |
| RO Conductivity | ro conductivity, permeate conductivity |

- Header row can be anywhere in the top 20 rows
- Minimum 3 recognized columns required
- Each data row becomes a separate measurement
- Missing values default to 0.0 (except pH — row is skipped if missing)

---

## Calculation Formulas

### LSI (Langelier Saturation Index)
```
TDS = conductivity × 0.67
A = (log10(TDS) - 1) / 10
B = -13.12 × log10(temp + 273.15) + 34.55
C = log10(hardness) - 0.4
D = log10(alkalinity)
pHs = (9.3 + A + B) - (C + D)
LSI = pH - pHs
```

### RSI (Ryznar Stability Index)
```
RSI = 2 × pHs - pH
```

### PSI (Puckorius Scaling Index)
```
phEquil = 1.465 × log10(alkalinity) + 4.54
PSI = 2 × pHs - phEquil
```

### Risk Scoring
- **Scaling (0-100):** Hardness 40%, Alkalinity 30%, pH 20%, LSI 10%
- **Corrosion (0-100):** Zinc 30%, Chloride 25%, pH 20%, RSI 15%, Larson-Skold 10%
- **Fouling (0-100):** Iron 40%, Phosphates 30%, Conductivity 20%, Silica 10%

### Health Score (0-100)
```
Chemistry (35%) + Risk Profile (35%) + Treatment (20%) + Stability (10%)
```
Status: >85 Excellent, >70 Good, >50 Fair, >30 Poor, else Critical

---

## Authentication Flow

1. **Signup:** Email + password + full name → Supabase `signUp()` → Email verification required
2. **Login:** Email/password via `signInWithPassword()` OR Google OAuth
3. **Email Verification:** `EmailVerificationScreen` with resend + check buttons
4. **Session:** Managed by Supabase (auto-persistent)

---

## Data Pipeline

1. Files uploaded to Supabase Storage → `factories` bucket
2. `syncWithDrive()` downloads all `.xlsx` files per factory
3. `UniversalExcelParser.parse()` → multi-row CoolingTowerData + ROData
4. Indices + Risk + Health calculated per measurement
5. `DataMergeService` upserts into `measurements_v2` (delete-then-insert, "Latest Wins")
6. `aggregatedDataProvider` queries `measurements_v2` → daily calculations → period averages
7. UI renders from aggregated data

---

## Missing Data Handling

- **Detection:** Parser checks each row for required keys (pH, alkalinity, conductivity, hardness, chloride, date)
- **Safe Mode:** Skip rows with missing required parameters
- **Accepted Risk Mode:** Replace missing values with averages, requires OTP verification, logged to `risk_acceptance_log`

---

## Known Issues & Status

### ✅ Fixed Bugs
| ID | Description |
|---|---|
| BUG-001 | Monthly date calculation crash in January |
| BUG-002 | Empty days list crash in aggregation |
| BUG-006 | `log10(0)` producing NaN in LSI/RSI |

### ⚠️ Open Issues (Pre-Production)
| ID | Severity | Description |
|---|---|---|
| BUG-003 | HIGH | PSI formula has unguarded `log10(alkalinity)` — NaN if alkalinity = 0 |
| BUG-004 | HIGH | DataMergeService filter syntax may be incorrect with Supabase RLS |
| BUG-005 | MEDIUM | Temperature hardcoded to 25°C for all index calculations |
| BUG-007 | MEDIUM | Sulfate always estimated from chloride (×0.5), never measured |
| BUG-008 | MEDIUM | Silica fouling contribution always zero (placeholder) |
| BUG-009 | LOW | Factory list not sorted by health score |
| BUG-010 | HIGH | V1 reports table only stores latest file's scores (historical data overwritten) |
| BUG-011 | HIGH | Stiff-Davis Index identical to LSI (no separate calculation) |
| BUG-012 | MEDIUM | Chloride-Sulfate ratio always 2.0 (useless metric) |
| BUG-013 | HIGH | Signup bypasses email verification gate |
| BUG-014 | CRITICAL | OTP not sent to user (Edge Function missing) |
| BUG-015 | HIGH | Missing data dialog not integrated into upload flow |
| BUG-016 | MEDIUM | "Remember me" checkbox has no effect |
| BUG-017 | MEDIUM | "Forgot password" button is a no-op |
| BUG-018 | HIGH | excel package crashes on certain file structures |
| BUG-019 | MEDIUM | All files treated as PeriodType.daily regardless of actual granularity |
| BUG-020 | LOW | `_findDateInMetadata()` always returns null (stub) |

### 🔴 CRITICAL: `calculation_engine.dart` Deleted
- **Date:** 2026-02-10
- **File:** `lib/services/calculation_engine.dart` (396 lines)
- **Impact:** ALL calculations are broken — indices, risk, health, recommendations
- **Status:** File must be restored before any further work
- **Content:** Contained `CalculationEngine` class with `calculateIndices()`, `assessRisk()`, `assessRO()`, `calculateHealth()`, `generateRecommendations()`, plus helper methods `_calcScore()`, `_getRiskLevel()`, `log10()`

---

## Changelog

### 2026-02-10 — Full System Audit
- Completed exhaustive 14-section audit of entire codebase
- Catalogued 20 bugs (3 fixed, 17 open including 4 critical/high)
- Created production readiness plan (6 phases, 34 tasks)
- **⚠️ `calculation_engine.dart` was deleted** — must be restored

### 2026-02-09 — Feature Enhancements (Phase 2-4)
- Enhanced `TrendsScreen` with real data from `aggregatedDataProvider`
- Enhanced `AlertsScreen` with WHY explanations and real data
- Enhanced `generateRecommendations()` with 6 alert types and detailed chemical reasoning
- Added missing data handling widgets (`MissingDataDialog`, `OtpConfirmationDialog`)
- Added `OtpVerificationService` for risk acceptance workflow
- Modified `UniversalExcelParser` to return validation metadata
- All modifications compile successfully (`flutter analyze` = 0 errors)

### 2026-02-09 — Critical Bug Fixes (Phase 1)
- Fixed BUG-001: January date crash in `aggregated_data_provider.dart`
- Fixed BUG-002: Empty days list crash in `aggregated_data_provider.dart`
- Fixed BUG-006: Log(0) NaN propagation in `calculation_engine.dart`

### 2026-02-08 — Engineering Audit Report
- Generated comprehensive audit of chemistry calculations, assumptions, and risks
- Identified V1/V2 pipeline split as critical architecture issue
- Documented all scientific assumptions (hardcoded temperature, estimated sulfate)

### Pre-2026-02-08 — Initial Development
- Built complete Flutter app with 7-tab navigation
- Implemented Supabase Auth (email/password + Google OAuth)
- Built `UniversalExcelParser` with header synonym matching
- Implemented `CalculationEngine` with LSI/RSI/PSI formulas
- Created `aggregatedDataProvider` with daily-first aggregation
- Built Dashboard, Trends, Alerts, Factories screens
- Implemented factory sub-navigation with 6 tabs
- Created V2 data model (`MeasurementV2`) and `DataMergeService`

---

## Production Readiness Status

| Category | Status |
|---|---|
| Core Calculations | 🔴 **BROKEN** — calculation_engine.dart deleted |
| Authentication | 🟡 Functional but has bypass (BUG-013) |
| Excel Parsing | 🟡 Works for valid files, some crash at library level |
| Dashboard UI | 🟢 Functional (depends on calculation engine restoration) |
| Trends UI | 🟢 Functional with real data |
| Alerts UI | 🟢 Enhanced with WHY explanations |
| Missing Data Handling | 🟡 Widgets exist but not wired into flow |
| OTP System | 🔴 Email sending not implemented |
| Automated Tests | 🔴 None exist |
| Security | 🟡 Hardcoded credentials, email bypass |
