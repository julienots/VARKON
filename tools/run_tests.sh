#!/bin/bash
# Runs the headless test suite. Fails if any test fails OR if any GDScript runtime error
# is printed (a script error aborts a test method silently otherwise).
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
timeout 300 $GODOT --headless --import >/dev/null 2>&1
LOG=$(mktemp)
timeout 1200 $GODOT --headless --path . res://tests/test_runner.tscn -- "$@" 2>&1 | tee "$LOG" | grep -E "PASS|FAIL|tests,|SCRIPT ERROR|at: "
STATUS=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
	echo "Script errors detected during tests:"
	grep -A1 "SCRIPT ERROR" "$LOG"
	STATUS=1
fi
rm -f "$LOG"
exit $STATUS
