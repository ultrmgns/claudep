# claudep

Claude Private Edition with automatic document-to-markdown conversion.

Built on top of [claude-private](../claude-code-source/claude-private-release/) (no telemetry), claudep adds a pre-processing layer that converts document files to Markdown before they enter the conversation — saving tokens, reducing cost, and improving response quality.

## Why

PDF, DOCX, PPTX, and similar formats carry massive visual/layout metadata (fonts, positioning, styles, XML markup) that wastes tokens without adding semantic value. A 214KB PDF becomes a 6.4KB markdown file. An 18KB DOCX binary blob becomes clean readable text. The content is identical — the packaging is what changes.

### Format decision table

The core principle: **if a format exists primarily for visual presentation/layout rather than semantic content, convert it. If it carries structured data or is already machine-friendly, leave it alone.**

| Format | Convert? | Reasoning | Tool |
|---|---|---|---|
| **PDF** (.pdf) | **Yes** | Layout coordinates, font metrics, page breaks — pure visual overhead | pdftotext + tesseract OCR |
| **DOCX** (.docx) | **Yes** | XML zip with massive style/theme/relationship metadata | pandoc + tesseract OCR |
| **DOC** (.doc) | **Yes** | Legacy binary Word — same content, worse container | libreoffice + pandoc |
| **RTF** (.rtf) | **Yes** | Rich text formatting commands, all visual | pandoc |
| **ODT** (.odt) | **Yes** | OpenDocument text — XML + styles, same story as DOCX | pandoc |
| **PPTX** (.pptx) | **Yes** | Slide layouts, transitions, master slides — content is just bullets/text | pandoc |
| **PPT** (.ppt) | **Yes** | Legacy PowerPoint, same reasoning | libreoffice + pandoc |
| **ODP** (.odp) | **Yes** | OpenDocument presentation | libreoffice + pandoc |
| **EPUB** (.epub) | **Yes** | XHTML + CSS styling for ebook readers | pandoc |
| **Pages** (.pages) | **Yes** | Apple's proprietary, heavy formatting | libreoffice + pandoc |
| **Keynote** (.key) | **Yes** | Apple presentation format | libreoffice + pandoc |
| | | | |
| **XLSX/XLS** (.xlsx/.xls) | **No** | Structured tabular data — cell relationships, formulas, sheet references. Markdown tables can't represent this faithfully | — |
| **ODS** (.ods) | **No** | OpenDocument spreadsheet — same as XLSX reasoning | — |
| **CSV/TSV** (.csv/.tsv) | **No** | Already plain text, minimal overhead | — |
| **HTML** (.html) | **No** | Already a semantic markup language, close to markdown. Often contains embedded structured data (tables, forms, microdata) that matters | — |
| **XML** (.xml) | **No** | Structured data format, already text | — |
| **JSON/YAML** (.json/.yaml) | **No** | Machine-native structured data | — |
| **LaTeX** (.tex) | **No** | Already text markup; converting loses math notation precision | — |
| **Plain text** (.txt) | **No** | Already minimal | — |
| **Markdown** (.md) | **No** | Already the target format | — |
| **Source code** | **No** | Already text | — |

## Token Savings Benchmark

Tested 2026-04-03 against `claude-private` (no conversion). Same prompt for each pair: _"Read the file and give me exactly 3 bullet points summarizing the key findings."_ Both use `--allowedTools 'Read,Bash'` in headless `-p` mode.

### Results

| Test | Method | Total Input Tokens | Output | Turns | Cost | Time |
|---|---|---:|---:|---:|---:|---:|
| A | claude-private + DOCX (raw) | 67,947 | 758 | 4 | $0.0775 | 31.7s |
| B | **claudep** + DOCX (→ markdown) | 35,546 | 297 | 2 | $0.0745 | 9.7s |
| | | | | | | |
| C | claude-private + PDF 2pg (raw) | 34,194 | 342 | 3 | $0.1318 | 12.5s |
| D | **claudep** + PDF 2pg (→ markdown) | 33,148 | 232 | 2 | $0.0578 | 8.1s |
| | | | | | | |
| E | claude-private + PDF 19pg (raw) | 56,521 | 478 | 3 | $0.2358 | 23.0s |
| F | **claudep** + PDF 19pg (→ markdown) | 228,236 | 1,313 | 10 | $0.2930 | 39.0s |

### Summary

| Document | Tokens | Cost | Time | Turns |
|---|---|---|---|---|
| **DOCX** (18 KB) | **-47.7%** | -3.9% | **-69.3%** | 4 → 2 |
| **PDF 2 pages** (214 KB) | -3.1% | **-56.1%** | **-35.8%** | 3 → 2 |
| **PDF 19 pages** (6.3 MB) | +303.8% | +24.3% | +69.4% | 3 → 10 |

### Analysis

**DOCX is a clear win across the board.** Claude-private can't read DOCX natively — it resorts to spawning Python/Bash to extract text, burning extra turns and tokens on tool overhead. Claudep feeds clean markdown directly: half the turns, half the tokens, 3x faster.

**Small PDFs (1-5 pages) are a strong win.** The 2-page GDPR document went from $0.13 to $0.06 — a 56% cost reduction. The markdown (134 lines) fits in a single Read call, avoiding multi-turn overhead entirely.

**Large PDFs (10+ pages) are currently worse.** The Anthropic API handles PDFs natively as document blocks — one efficient chunk. The converted markdown (4,379 lines for 19 pages) exceeds the Read tool's 2,000-line default, requiring multiple round trips. Each turn re-sends the ~15K system prompt, causing token inflation.

### Why the 5-page PDF threshold

claudep automatically skips markdown conversion for PDFs over 5 pages. This is based on the benchmark data above, but the real-world motivation is batch processing.

Consider processing a folder of 1-3 page documents — payslips, invoices, support tickets, compliance forms, receipts, shipping labels. These are the most common PDFs in enterprise workflows: short, structured, and processed in volume. A single payslip PDF is ~100-300KB of layout data wrapping ~2KB of actual text (name, amounts, dates). At scale, the savings compound fast:

| Scenario | Files | Raw PDF cost | claudep cost | Saved |
|---|---|---|---|---|
| 100 payslips (1 pg each) | 100 | ~$13.00 | ~$5.70 | **~$7.30** |
| 500 support tickets (2 pg) | 500 | ~$65.00 | ~$29.00 | **~$36.00** |
| 50 compliance forms (3 pg) | 50 | ~$6.50 | ~$2.90 | **~$3.60** |

_(Estimates based on the 2-page PDF benchmark: $0.132 raw vs $0.058 converted per file.)_

For large PDFs (research papers, legal contracts, annual reports), the API's native document block handling is more efficient because it sends the entire PDF in one shot. Markdown conversion of a 20+ page document produces thousands of lines that require multiple Read tool calls, each re-sending the ~15K system prompt — the multi-turn overhead erases the savings.

The threshold is configurable: `CLAUDEP_MAX_PDF_PAGES=10` or `doc2md --max-pdf-pages 10`.

### File size compression

| File | Source | Markdown | Ratio |
|---|---|---|---|
| GDPR_DOC_2.7.pdf (2 pages) | 214 KB | 6.4 KB | **33.8x** smaller |
| openclaw disaster (19 pages) | 6.3 MB | 232 KB | **27.5x** smaller |
| openclaw-viability-report.docx | 18 KB | 19 KB | ~1x (small doc, mostly text) |

## Install

```bash
# From source
git clone <repo> && cd claudep
bash install.sh

# Or from .run
chmod +x claudep-1.0.0.run
./claudep-1.0.0.run
```

The installer checks for required dependencies (`poppler-utils`, `pandoc`) and warns if they're missing. It also detects optional tools (`tesseract-ocr` for OCR, `libreoffice` for legacy formats) and reports what's enabled. If anything is missing, install it:

```bash
sudo apt install poppler-utils pandoc            # required
sudo apt install tesseract-ocr                   # optional: OCR for embedded images in PDF/DOCX
sudo apt install libreoffice                     # optional: legacy formats (.doc, .ppt, .odp, .pages, .key)
```

## Usage

```bash
# Interactive (same as claude-private)
claudep

# Auto-converts documents referenced in prompts
claudep -p "Read /path/to/report.pdf and summarize the key findings"

# Skip conversion
claudep --no-convert -p "Read /path/to/report.pdf as raw"

# Override PDF page threshold (default: 5)
CLAUDEP_MAX_PDF_PAGES=10 claudep -p "Read /path/to/big-report.pdf and summarize"

# Standalone converter
doc2md report.pdf                         # -> report.md
doc2md presentation.pptx output.md        # -> output.md
doc2md --max-pdf-pages 10 big.pdf out.md  # custom threshold
```

## Requires

- `claude-private` installed (provides `claude-notelemetry` binary)
- Linux x86_64
