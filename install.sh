#!/bin/bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$HOME/.pi/agent"

echo "=== pi-config installer ==="
echo "Source: $CONFIG_DIR"
echo "Target: $AGENT_DIR"
echo ""

# Ensure target exists
mkdir -p "$AGENT_DIR"

# Backup existing skills (once)
if [ -d "$AGENT_DIR/skills" ] && [ ! -L "$AGENT_DIR/skills" ]; then
    BACKUP="$AGENT_DIR/skills.backup.$(date +%s)"
    cp -r "$AGENT_DIR/skills" "$BACKUP"
    echo "Backed up existing skills to: $BACKUP"
fi

# Remove old skills dir and symlink the whole directory
rm -rf "$AGENT_DIR/skills"
ln -s "$CONFIG_DIR/skills" "$AGENT_DIR/skills"
echo "Linked skills/ → $CONFIG_DIR/skills"

# Symlink config files (but never auth.json)
for file in models.json settings.json; do
    if [ -f "$CONFIG_DIR/$file" ]; then
        rm -f "$AGENT_DIR/$file"
        ln -s "$CONFIG_DIR/$file" "$AGENT_DIR/$file"
        echo "Linked $file"
    fi
done

echo ""
echo "Done. Restart pi if it's running."
echo ""
echo "Current skills:"
ls "$AGENT_DIR/skills/"
