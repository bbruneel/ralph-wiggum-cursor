#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

assert_contains() {
  local file="$1"
  local pattern="$2"

  if ! grep -q "$pattern" "$file"; then
    echo "Assertion failed: expected '$pattern' in $file" >&2
    exit 1
  fi
}

main() {
  local workspace install_log
  workspace="$(mktemp -d)"
  install_log="$workspace/install.log"

  git -C "$workspace" init -q
  mkdir -p "$workspace/.ralph"

  cat > "$workspace/.ralph/progress.md" <<'EOF'
# Progress Log

custom-progress-sentinel
EOF

  cat > "$workspace/.ralph/guardrails.md" <<'EOF'
# Ralph Guardrails

custom-guardrail-sentinel
EOF

  cat > "$workspace/RALPH_TASK.md" <<'EOF'
# Existing Task

custom-task-sentinel
EOF

  (
    cd "$workspace"
    INSTALL_GUM=0 \
    INSTALL_TEXTUAL=0 \
    REPO_RAW="file://$REPO_DIR" \
    bash "$REPO_DIR/install.sh" >"$install_log"
  )

  assert_contains "$workspace/.ralph/progress.md" "custom-progress-sentinel"
  assert_contains "$workspace/.ralph/guardrails.md" "custom-guardrail-sentinel"
  assert_contains "$workspace/RALPH_TASK.md" "custom-task-sentinel"

  test -f "$workspace/.ralph/signals.log"
  test -f "$workspace/.ralph/runtime.env"
  test -f "$workspace/.ralph/session-brief.md"
  test -f "$workspace/.ralph/navigation-brief.md"
  test -f "$workspace/.ralph/read-trace.tsv"
  test -f "$workspace/.cursor/ralph-scripts/ralph-tui.py"

  assert_contains "$install_log" "Preserved .ralph/progress.md"
  assert_contains "$install_log" "Preserved RALPH_TASK.md"

  echo "installer upgrade smoke test passed"
}

main "$@"
