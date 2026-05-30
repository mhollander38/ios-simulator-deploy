#!/bin/bash
set -euo pipefail

SKILL_NAME="ios-simulator-deploy"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/skills/$SKILL_NAME/skill.md"
SKILL_DEST="$HOME/.claude/skills/$SKILL_NAME"

if [ ! -f "$SKILL_SRC" ]; then
  echo "Error: skill.md not found at $SKILL_SRC" >&2
  exit 1
fi

mkdir -p "$SKILL_DEST"
cp "$SKILL_SRC" "$SKILL_DEST/skill.md"

echo "Installed $SKILL_NAME to $SKILL_DEST/skill.md"
echo "Restart Claude Code to activate the skill."
