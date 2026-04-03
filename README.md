# claudep

Claude Private Edition with automatic document-to-markdown conversion. This is specialized for work with a very very large number of documents that contain text data (no graphs). In my testing, it's twice as fast and costs magnitudes less for hundreds+ small document ingestion (payslips, invoices, support tickets, compliance forms, receipts). Please read bellow, the tests will show why it's amazing for small documents and why I implemented the threshold for number of pages.

No telemetry. Token-efficient document ingestion. Drop-in replacement for `claude`.

## Quick start

Download the `.run` file and install:

```bash
chmod +x claudep-1.0.0.run
./claudep-1.0.0.run
```

Then just use it:

```bash
claudep
```

That's it. Everything works the same as `claude` - but when you ask it to read a PDF, DOCX, PPTX, or any other supported document, it automatically converts it to Markdown before ingestion, saving tokens and cost. You don't need to do anything different.

The integration added a couple of tools that can also be used externally if you want to pre-convert documents yourself:

```bash
doc2md report.pdf                    # -> report.md
doc2md presentation.pptx output.md   # -> output.md
```

## How it works

The conversion logic is built into the Read tool at the source level (`FileReadTool.ts`). When the tool detects a document file by extension, it runs it through a conversion pipeline (`documentConverter.ts`) before returning the content - the model receives clean Markdown text instead of binary data or base64-encoded blobs.

The flow inside the binary:

```
Read("report.pdf")
  → detectExtension(.pdf)
  → convertDocumentToMarkdown()    # pdftotext + tesseract OCR
  → return as type: 'text'         # line numbers, offset/limit, dedup caching
```

No extra tool calls, no wrapper scripts, no prompting tricks. The model just sees text.

### What was changed in the source

Three files modified, one created:

| File | Change |
|---|---|
| `src/utils/documentConverter.ts` | **New.** Conversion engine - routes formats to the right CLI tool, handles OCR, temp file cleanup, error reporting |
| `src/tools/FileReadTool/FileReadTool.ts` | Replaced the PDF base64 pipeline with a unified document conversion branch. Added binary extension bypass for convertible formats |
| `src/tools/FileReadTool/prompt.ts` | Updated the Read tool's system prompt to document supported document formats |
| `src/constants/files.ts` | No changes needed - the binary extension allowlist is bypassed at the call site |

The conversion engine calls standard system tools internally via `execFileNoThrow()`:

| Format | Internal tool | OCR |
|---|---|---|
| PDF (.pdf) | `pdftotext` (poppler-utils) | Yes - `pdfimages` + `tesseract` |
| DOCX (.docx) | `pandoc` | Yes - `--extract-media` + `tesseract` |
| RTF, ODT, PPTX, EPUB | `pandoc` | No |
| DOC, PPT, ODP, Pages, Keynote | `libreoffice --headless` → `pandoc` | No |

These are system packages, not bundled libraries. The installer checks for them and tells you what's missing.

### What is NOT converted

| Format | Why |
|---|---|
| **XLSX/XLS/ODS** | Structured tabular data - cell relationships, formulas, sheet references. Markdown tables can't represent this faithfully |
| **HTML** | Already a semantic markup language, close to markdown. Often contains embedded structured data (tables, forms, microdata) that matters |
| **CSV/TSV** | Already plain text, minimal overhead |
| **JSON/XML/YAML** | Machine-native structured data |
| **LaTeX** (.tex) | Already text markup; converting loses math notation precision |
| **Plain text, Markdown, source code** | Already the target format or equivalent |

## PDF page threshold

claudep skips markdown conversion for PDFs over 5 pages and lets the API handle them natively instead.

**Why 5 pages?** The real-world use case is batch processing short documents — payslips, invoices, support tickets, compliance forms, receipts. These are 1-3 pages each, processed in volume. A single payslip PDF is ~100-300KB of layout data wrapping ~2KB of actual text. Converting to markdown saves 56% on cost per file. At scale:

| Scenario | Files | Raw cost | claudep cost | Saved |
|---|---|---|---|---|
| 100 payslips (1 pg each) | 100 | ~$13.00 | ~$5.70 | **~$7.30** |
| 500 support tickets (2 pg) | 500 | ~$65.00 | ~$29.00 | **~$36.00** |
| 50 compliance forms (3 pg) | 50 | ~$6.50 | ~$2.90 | **~$3.60** |

For large PDFs (research papers, legal contracts, annual reports), the API handles them natively as document blocks in one shot. Markdown conversion of a 20+ page document produces thousands of lines that need multiple Read calls — the multi-turn overhead erases the savings.

The threshold is configurable: `CLAUDEP_MAX_PDF_PAGES=10 claudep` or `doc2md --max-pdf-pages 10`.

## Token savings benchmark

Tested 2026-04-03 against `claude-private` (no conversion). Same prompt, same allowed tools, headless mode.

| Document | Tokens | Cost | Time | Turns |
|---|---|---|---|---|
| **DOCX** (18 KB) | **-47.7%** | -3.9% | **-69.3%** | 4 → 2 |
| **PDF 2 pages** (214 KB) | -3.1% | **-56.1%** | **-35.8%** | 3 → 2 |
| **PDF 19 pages** (6.3 MB) | +303.8% | +24.3% | +69.4% | 3 → 10 |

<details>
<summary>Full results table</summary>

| Test | Method | Total Input Tokens | Output | Turns | Cost | Time |
|---|---|---:|---:|---:|---:|---:|
| A | claude-private + DOCX (raw) | 67,947 | 758 | 4 | $0.0775 | 31.7s |
| B | **claudep** + DOCX (→ markdown) | 35,546 | 297 | 2 | $0.0745 | 9.7s |
| C | claude-private + PDF 2pg (raw) | 34,194 | 342 | 3 | $0.1318 | 12.5s |
| D | **claudep** + PDF 2pg (→ markdown) | 33,148 | 232 | 2 | $0.0578 | 8.1s |
| E | claude-private + PDF 19pg (raw) | 56,521 | 478 | 3 | $0.2358 | 23.0s |
| F | **claudep** + PDF 19pg (→ markdown) | 228,236 | 1,313 | 10 | $0.2930 | 39.0s |

</details>

### File size compression

| File | Source | Markdown | Ratio |
|---|---|---|---|
| GDPR_DOC_2.7.pdf (2 pages) | 214 KB | 6.4 KB | **33.8x** smaller |
| openclaw disaster (19 pages) | 6.3 MB | 232 KB | **27.5x** smaller |
| openclaw-viability-report.docx | 18 KB | 19 KB | ~1x (small doc, mostly text) |

![scr1](https://github.com/user-attachments/assets/64776174-ca2b-46bb-b6ed-4d1b1c6b0d8b)

## System dependencies

The binary calls these tools internally. The installer checks for them:

```bash
sudo apt install poppler-utils pandoc            # required
sudo apt install tesseract-ocr                   # optional: OCR for embedded images
sudo apt install libreoffice                     # optional: .doc, .ppt, .odp, .pages, .key
```

## Built on

- [claude-private](https://github.com/ultrmgns/claude-private) - Claude Code CLI with all telemetry removed
