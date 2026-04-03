#!/bin/bash
# Creates a self-extracting .run installer for claudep
# Bundles: claude-notelemetry binary + claudep wrapper + doc2md converter
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.0.0"
OUTPUT="$SCRIPT_DIR/claudep-${VERSION}.run"

# Find the patched binary
BINARY="${CLAUDE_NOTELEMETRY_BIN:-$HOME/.local/bin/claude-notelemetry}"
if [[ ! -x "$BINARY" ]]; then
    echo "Error: claude-notelemetry binary not found at $BINARY" >&2
    echo "Set CLAUDE_NOTELEMETRY_BIN=/path/to/binary or install claude-private first." >&2
    exit 1
fi

BINARY_SIZE=$(du -h "$BINARY" | cut -f1)
echo "Bundling claude-notelemetry ($BINARY_SIZE) from: $BINARY"
echo "Creating self-extracting installer..."

cat > "$OUTPUT" << 'HEADER'
#!/bin/bash
# claudep — Claude Private Edition + Document Conversion
# Self-extracting installer
#
# Usage: chmod +x claudep-1.0.0.run && ./claudep-1.0.0.run

set -e

PREFIX="$HOME/.local"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix|--prefix=*) [[ "$1" == *=* ]] && PREFIX="${1#*=}" || { PREFIX="$2"; shift; }; shift ;;
        --help|-h) echo "Usage: $0 [--prefix /path]  (default: ~/.local)"; exit 0 ;;
        *) shift ;;
    esac
done

echo "=== claudep v1.0.0 — Claude Private + Document Conversion ==="
echo "Installing to: ${PREFIX}/bin/"

ARCHIVE_LINE=$(awk '/^__ARCHIVE_MARKER__$/{print NR + 1; exit 0; }' "$0")
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

tail -n +"$ARCHIVE_LINE" "$0" | tar xz -C "$TMPDIR"

mkdir -p "${PREFIX}/bin"
cp "$TMPDIR/claude-notelemetry" "${PREFIX}/bin/claude-notelemetry"
cp "$TMPDIR/claudep" "${PREFIX}/bin/claudep"
cp "$TMPDIR/doc2md" "${PREFIX}/bin/doc2md"
chmod +x "${PREFIX}/bin/claude-notelemetry" "${PREFIX}/bin/claudep" "${PREFIX}/bin/doc2md"

echo ""
echo "Installed:"
echo "  claudep              — Main executable"
echo "  doc2md               — Standalone document converter"
echo "  claude-notelemetry   — Patched binary (no telemetry)"
echo ""

# Check dependencies
MISSING=""
command -v pdftotext >/dev/null 2>&1 || MISSING="$MISSING poppler-utils"
command -v pandoc >/dev/null 2>&1 || MISSING="$MISSING pandoc"
if [[ -n "$MISSING" ]]; then
    echo "Missing required dependencies:$MISSING"
    echo "Install with: sudo apt install$MISSING"
    echo ""
fi

command -v tesseract >/dev/null 2>&1 && echo "  OCR:         enabled" || echo "  OCR:         disabled (optional: sudo apt install tesseract-ocr)"
command -v libreoffice >/dev/null 2>&1 && echo "  Legacy docs: enabled" || echo "  Legacy docs: disabled (optional: sudo apt install libreoffice)"
echo ""
echo "Usage: claudep"
echo ""

if ! echo "$PATH" | grep -q "${PREFIX}/bin"; then
    echo "Add to PATH:"
    echo "  echo 'export PATH=\"${PREFIX}/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
fi
exit 0

__ARCHIVE_MARKER__
HEADER

# Bundle the binary + scripts into a compressed tarball appended to the header
tar czf - -C "$(dirname "$BINARY")" "$(basename "$BINARY")" \
          -C "$SCRIPT_DIR" claudep doc2md >> "$OUTPUT"
chmod +x "$OUTPUT"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Created: $OUTPUT ($SIZE)"
