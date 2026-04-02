#!/bin/bash
# claudep installer
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${1:-$HOME/.local}"
BIN_DIR="${PREFIX}/bin"

echo "=== claudep — Claude Private Edition + Document Conversion ==="
echo ""

# Check prerequisites
echo "Checking dependencies..."
MISSING=""

if ! command -v pdftotext >/dev/null 2>&1; then
    MISSING="$MISSING  poppler-utils (pdftotext, pdfimages)\n"
fi
if ! command -v pandoc >/dev/null 2>&1; then
    MISSING="$MISSING  pandoc\n"
fi

if [[ -n "$MISSING" ]]; then
    echo ""
    echo "Required dependencies missing:"
    echo -e "$MISSING"
    echo "Install with: sudo apt install poppler-utils pandoc"
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Check for claude-notelemetry (from claude-private)
if [[ ! -x "$BIN_DIR/claude-notelemetry" ]]; then
    echo ""
    echo "Warning: claude-notelemetry not found in $BIN_DIR"
    echo "claudep requires claude-private to be installed first."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Install
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/claudep" "$BIN_DIR/claudep"
cp "$SCRIPT_DIR/doc2md" "$BIN_DIR/doc2md"
chmod +x "$BIN_DIR/claudep" "$BIN_DIR/doc2md"

echo ""
echo "Installed to $BIN_DIR:"
echo "  claudep  — Main executable (drop-in claude replacement)"
echo "  doc2md   — Standalone document-to-markdown converter"
echo ""

# Optional deps
if command -v tesseract >/dev/null 2>&1; then
    echo "  OCR:         enabled (tesseract found)"
else
    echo "  OCR:         disabled (optional: sudo apt install tesseract-ocr)"
fi
if command -v libreoffice >/dev/null 2>&1; then
    echo "  Legacy docs: enabled (libreoffice found)"
else
    echo "  Legacy docs: disabled (optional: sudo apt install libreoffice)"
fi

echo ""
echo "Usage:"
echo "  claudep                                   # interactive session"
echo '  claudep -p "summarize /path/to/file.pdf"  # auto-converts, then queries'
echo "  doc2md report.pdf                          # standalone conversion"
echo ""

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "Add to PATH: export PATH=\"$BIN_DIR:\$PATH\""
fi
