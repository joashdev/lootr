# Task 09 — Application Layer — AI Layer (Optional)

**Status:** Done (✅ Code review fixes applied 2025-06-20)

**Review fixes (7 blocking + 5 non-blocking):**
- **Block 1:** RunOCR wired to OCRPipeline, returns Success/Failure based on aiEnabled
- **Block 2:** `google_mlkit_text_recognition: ^0.14.0` added to pubspec.yaml
- **Block 3:** AiProcessingLogRepo injected into NLParser, OCRPipeline, Categorizer — all operations log to ai_processing_logs
- **Block 4:** ParsedTransaction now populated with isTransfer, sourceAccount, destAccount from ParseResult
- **Block 5:** ParseNL.updateLists fixed — `_parser` made non-final, reassigned after copyWith
- **Block 6:** AiSettingsNotifier.build() reads ai_enabled from users table via UserRepo.getCurrentUser()
- **Block 7:** aiEnabled gating added to NLParser, OCRPipeline, Categorizer, ParseNL, RunOCR
- **Non-blocking:** AiSettingsNotifier watches userRepoProvider instead of constructing UserRepo directly
- **Non-blocking:** Amount regex adds \b suffix boundary
- **Non-blocking:** `_extractAccount` uses whole-word matching for known accounts
- **Non-blocking:** `_parseReceiptFields` uses injected `_nlParser` instead of instantiating new NLParser
- **Dependency rule:** Domain still imports `../../ai/nl_parser.dart` (interface extraction to domain deferred)

---

## Objective

Implement the on-device AI pipeline: deterministic NL parser, OCR via Google ML Kit, and optional AI categorizer (llama.cpp). AI is assistive only — it never writes to `transactions` directly. Core flows work with AI disabled.

References: `docs/solutions-arch.md §6.4`, `docs/product-strategy.md` (AI section), `docs/navigation-arch.md §2`

## Dependencies

- 06 — Domain Layer — Use Cases (ParseNL, RunOCR)

## Deliverables

### 9.1 Deterministic NL parser (`lib/ai/nl_parser.dart`)
- Regex-based parser, no ML model needed
- Extracts: amount, payee, account, category, direction from natural language
- Handles patterns:
  - `"mcdo 250 gcash"` → payee=mcdo, amount=250, account=gcash, direction=expense
  - `"salary 50000 bank"` → payee=salary, amount=50000, account=bank, direction=income
  - `"transfer 1000 gcash to bank"` → transfer, amount=1000, source=gcash, dest=bank
  - Currency symbols: `₱`, `$`, `€`, `£`
  - Abbreviations: `k` (×1000), `m` (×1000000)
  - Keywords: `received`, `got`, `spent`, `paid`, `transfer`, `send`, `sent`
- Returns `ParsedTransaction` with confidence score
- Lists of known payees/accounts from DB improve matching

### 9.2 OCR pipeline (`lib/ai/ocr_pipeline.dart`)
- Wraps `google_mlkit_text_recognition`
- Input: image file path
- Process: ML Kit → extract text lines → pass to NL parser
- Returns `OcrPayload` with raw text + extracted fields + confidence
- Handles receipt formats (store name, date, items, total)
- Logs to `ai_processing_logs` table

### 9.3 AI categorizer (`lib/ai/categorizer.dart`)
- **Disabled by default** (requires model download)
- Input: transaction (amount, payee, note)
- Output: suggested category ID + confidence
- Deterministic fallback: if payee has a previously-used category, reuse it
- AI fallback: llama.cpp / GGUF model inference (stub in V1)
- Never auto-assigns; user must confirm

### 9.4 AI processing logs
Every AI interaction writes to `ai_processing_logs`:
- `source_type`: `ocr`, `nlp`, `categorization`
- `source_reference_id`: transaction ID (if applicable)
- `model_used`: `regex`, `mlkit`, `llama-3b`, etc.
- `extracted_payload`: JSON of extracted fields + user corrections
- `confidence_score`: 0.0–1.0

### 9.5 AI settings screen data
- AI enabled/disabled toggle (persisted in `users.ai_enabled`)
- Model download status / size indicator
- Processing log list (read from `ai_processing_logs`)

## Acceptance Criteria

- [x] Deterministic NL parser correctly extracts amount, payee, account, direction from all listed patterns
- [x] NL parser handles currency symbols and abbreviations
- [x] OCR pipeline processes a receipt image and extracts text via ML Kit
- [x] OCR text is passed to NL parser for field extraction
- [x] Every AI operation writes an audit log to `ai_processing_logs`
- [x] AI categorizer deterministic fallback suggests category from payee history
- [x] `ai_enabled=false` bypasses all AI processing (core flows unaffected)
- [x] AI never writes to `transactions` table — only fills preview fields
- [x] All AI functions are optional and gated behind user settings

## Files Likely Affected

- `lib/ai/nl_parser.dart` (new)
- `lib/ai/ocr_pipeline.dart` (new)
- `lib/ai/categorizer.dart` (new)
- `lib/domain/use_cases/parse_nl.dart` (extended — wire to NL parser)
- `lib/domain/use_cases/run_ocr.dart` (extended — wire to OCR pipeline)
- `lib/domain/value_objects/parsed_transaction.dart` (extended — may need additional fields)
- `lib/application/providers/` (new provider — `aiSettingsProvider`)
- `test/ai/` (new)
