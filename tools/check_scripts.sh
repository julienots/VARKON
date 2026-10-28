#!/bin/bash
# Lists GDScript parse/compile errors with file:line by loading the test runner headless.
cd "$(dirname "$0")/.."
timeout 200 godot --headless --import >/dev/null 2>&1
timeout 120 godot --headless --path . res://tests/test_runner.tscn -- --only=__none__ 2>&1 | grep -A1 -E "SCRIPT ERROR|Parse Error" | grep -E "Error|at:" | sed 's/^ *//' | paste - - | sort -u | head -${1:-60}
