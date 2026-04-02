#!/bin/bash
# Creates a self-extracting .run installer for claudep
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.0.0"
OUTPUT="$SCRIPT_DIR/claudep-${VERSION}.run"

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

# Run the bundled installer
bash "$TMPDIR/install.sh" "$PREFIX" < /dev/tty || bash "$TMPDIR/install.sh" "$PREFIX" <<< "y"

exit 0

__ARCHIVE_MARKER__
HEADER

tar czf - -C "$SCRIPT_DIR" claudep doc2md install.sh README.md >> "$OUTPUT"
chmod +x "$OUTPUT"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Created: $OUTPUT ($SIZE)"
