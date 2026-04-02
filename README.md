# claudep

Claude Private Edition with automatic document-to-markdown conversion.

Built on top of [claude-private](../claude-code-source/claude-private-release/) (no telemetry), claudep adds a pre-processing layer that converts document files to Markdown before they enter the conversation — saving tokens, reducing cost, and improving response quality.

## Why

PDF, DOCX, PPTX, and similar formats carry massive visual/layout metadata (fonts, positioning, styles, XML markup) that wastes tokens without adding semantic value. A 6MB PDF that becomes a 50KB markdown file delivers the same content at a fraction of the token cost.

**Formats converted to Markdown:**

| Format | Tool | OCR |
|---|---|---|
| PDF (.pdf) | pdftotext | Yes (tesseract) |
| Word (.docx) | pandoc | Yes (tesseract) |
| Word legacy (.doc) | libreoffice + pandoc | No |
| PowerPoint (.pptx) | pandoc | No |
| PowerPoint legacy (.ppt) | libreoffice + pandoc | No |
| Rich Text (.rtf) | pandoc | No |
| OpenDocument Text (.odt) | pandoc | No |
| OpenDocument Presentation (.odp) | libreoffice + pandoc | No |
| EPUB (.epub) | pandoc | No |
| Apple Pages (.pages) | libreoffice + pandoc | No |
| Apple Keynote (.key) | libreoffice + pandoc | No |

**Formats left as-is:** XLSX/XLS (structured data), HTML (already markup), CSV/JSON/XML/YAML (machine-native).

## Install

```bash
# From source
git clone <repo> && cd claudep
bash install.sh

# Or from .run
chmod +x claudep-1.0.0.run
./claudep-1.0.0.run
```

### Dependencies

**Required:**
```bash
sudo apt install poppler-utils pandoc
```

**Optional:**
```bash
sudo apt install tesseract-ocr   # OCR for embedded images in PDF/DOCX
sudo apt install libreoffice      # Legacy formats (.doc, .ppt, .odp, .pages, .key)
```

## Usage

```bash
# Interactive (same as claude-private)
claudep

# Auto-converts documents referenced in prompts
claudep -p "Read /path/to/report.pdf and summarize the key findings"

# Skip conversion
claudep --no-convert -p "Read /path/to/report.pdf as raw"

# Standalone converter
doc2md report.pdf                    # -> report.md
doc2md presentation.pptx output.md   # -> output.md
```

## Requires

- `claude-private` installed (provides `claude-notelemetry` binary)
- Linux x86_64
