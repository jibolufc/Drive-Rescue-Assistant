#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/macos-engine"
VENV_DIR="$BUILD_ROOT/venv"
DIST_DIR="$BUILD_ROOT/dist"
ENGINE_PATH="$DIST_DIR/DriveRescueEngine"
PYTHON_BUILD="${PYTHON_BUILD:-/Library/Frameworks/Python.framework/Versions/3.12/bin/python3}"

if [[ ! -x "$PYTHON_BUILD" ]]; then
  printf 'Universal Python 3.12 was not found at %s\n' "$PYTHON_BUILD" >&2
  printf 'Set PYTHON_BUILD to a universal2 Python 3.10 or newer.\n' >&2
  exit 1
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  "$PYTHON_BUILD" -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c "import PyInstaller" >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m pip install --upgrade pip pyinstaller
fi

rm -rf "$DIST_DIR" "$BUILD_ROOT/work" "$BUILD_ROOT/DriveRescueEngine.spec"

"$VENV_DIR/bin/python" -m PyInstaller \
  --noconfirm \
  --clean \
  --onefile \
  --target-arch universal2 \
  --name DriveRescueEngine \
  --paths "$ROOT_DIR/src" \
  --distpath "$DIST_DIR" \
  --workpath "$BUILD_ROOT/work" \
  --specpath "$BUILD_ROOT" \
  "$ROOT_DIR/script/cli_entry.py"

file "$ENGINE_PATH"
printf '%s\n' "$ENGINE_PATH"
