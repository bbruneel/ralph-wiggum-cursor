#!/bin/bash
# Ralph Wiggum: One-click installer
# Usage: curl -fsSL https://raw.githubusercontent.com/FX-991ES-Plus-C/cheap_ralph-wiggum-cursor/main/install.sh | bash

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/FX-991ES-Plus-C/cheap_ralph-wiggum-cursor/main}"
WORKSPACE_ROOT="$(pwd)"

echo "═══════════════════════════════════════════════════════════════════"
echo "🐛 Ralph Wiggum Installer"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "⚠️  Warning: Not in a git repository."
  echo "   Ralph works best with git for state persistence."
  echo ""
  echo "   Run: git init"
  echo ""
fi

# Check for cursor-agent CLI
if ! command -v cursor-agent &> /dev/null; then
  echo "⚠️  Warning: cursor-agent CLI not found."
  echo "   Install via: curl https://cursor.com/install -fsS | bash"
  echo ""
fi

# Check for gum and offer to install
if ! command -v gum &> /dev/null; then
  echo "📦 gum not found (provides beautiful CLI menus)"
  
  # Auto-install if INSTALL_GUM=1 or prompt user
  SHOULD_INSTALL=""
  if [[ "${INSTALL_GUM:-}" == "1" ]]; then
    SHOULD_INSTALL="y"
  elif [[ "${INSTALL_GUM:-}" == "0" ]]; then
    SHOULD_INSTALL="n"
  else
    read -p "   Install gum? [y/N] " -n 1 -r < /dev/tty
    echo
    SHOULD_INSTALL="$REPLY"
  fi
  
  if [[ "$SHOULD_INSTALL" =~ ^[Yy]$ ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if command -v brew &> /dev/null; then
        echo "   Installing via Homebrew..."
        brew install gum
      else
        echo "   ⚠️  Homebrew not found. Install manually: brew install gum"
      fi
    elif [[ -f /etc/debian_version ]]; then
      echo "   Installing via apt..."
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt update && sudo apt install -y gum
    elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
      echo "   Installing via dnf..."
      echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
      sudo dnf install -y gum
    else
      echo "   ⚠️  Unknown Linux distro. Install manually: https://github.com/charmbracelet/gum#installation"
    fi
  fi
  echo ""
fi

write_file_if_missing() {
  local path="$1"

  if [[ -f "$path" ]]; then
    echo "✓ Preserved $path"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "✓ Created $path"
}

# =============================================================================
# CREATE DIRECTORIES
# =============================================================================

echo "📁 Creating directories..."
mkdir -p .cursor/ralph-scripts
mkdir -p .ralph

# =============================================================================
# DOWNLOAD SCRIPTS
# =============================================================================

echo "📥 Downloading Ralph scripts..."

SCRIPTS=(
  "ralph-common.sh"
  "ralph-setup.sh"
  "ralph-loop.sh"
  "ralph-once.sh"
  "ralph-stop.sh"
  "ralph-parallel.sh"
  "ralph-tui.py"
  "stream-parser.sh"
  "task-parser.sh"
  "ralph-retry.sh"
  "init-ralph.sh"
)

for script in "${SCRIPTS[@]}"; do
  if curl -fsSL "$REPO_RAW/scripts/$script" -o ".cursor/ralph-scripts/$script" 2>/dev/null; then
    chmod +x ".cursor/ralph-scripts/$script"
  else
    echo "   ⚠️  Could not download $script (may not exist yet)"
  fi
done

echo "✓ Scripts installed to .cursor/ralph-scripts/"

# =============================================================================
# RALPH DASHBOARD — nested uv project (does not touch the host pyproject.toml)
# =============================================================================

setup_ralph_dashboard_env() {
  local dash_dir="$WORKSPACE_ROOT/.cursor/ralph-dashboard"
  local pyproject="$dash_dir/pyproject.toml"
  local lockfile="$dash_dir/uv.lock"
  local venv_py="$dash_dir/.venv/bin/python"

  mkdir -p "$dash_dir"

  if ! curl -fsSL "$REPO_RAW/scripts/ralph-dashboard/pyproject.toml" -o "$pyproject" 2>/dev/null; then
    echo "   ⚠️  Could not download scripts/ralph-dashboard/pyproject.toml (dashboard bootstrap skipped)"
    return 1
  fi
  echo "✓ Installed $pyproject"

  if ! curl -fsSL "$REPO_RAW/scripts/ralph-dashboard/uv.lock" -o "$lockfile" 2>/dev/null; then
    echo "   ⚠️  Could not download scripts/ralph-dashboard/uv.lock"
    return 1
  fi
  echo "✓ Installed $lockfile"

  if [[ -x "$venv_py" ]] && "$venv_py" - <<'PY' 2>/dev/null; then
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("textual") else 1)
PY
    echo "✓ Ralph dashboard venv already has Textual"
    return 0
  fi

  if [[ "${INSTALL_TEXTUAL:-}" == "0" ]]; then
    echo "Skipping dashboard venv (INSTALL_TEXTUAL=0). To run the dashboard later:"
    echo "  cd .cursor/ralph-dashboard && uv sync"
    return 0
  fi

  local SHOULD_INSTALL_TEXTUAL=""
  if [[ "${INSTALL_TEXTUAL:-}" == "1" ]]; then
    SHOULD_INSTALL_TEXTUAL="y"
  elif [[ -r /dev/tty ]]; then
    read -p "   Install Textual dashboard in isolated .cursor/ralph-dashboard (uv)? [Y/n] " -n 1 -r < /dev/tty
    echo
    if [[ -z "${REPLY:-}" ]] || [[ "$REPLY" =~ ^[Yy]$ ]]; then
      SHOULD_INSTALL_TEXTUAL="y"
    else
      SHOULD_INSTALL_TEXTUAL="n"
    fi
  else
    SHOULD_INSTALL_TEXTUAL="y"
  fi

  if [[ ! "$SHOULD_INSTALL_TEXTUAL" =~ ^[Yy]$ ]]; then
    echo "Skipped. When ready: cd .cursor/ralph-dashboard && uv sync"
    return 0
  fi

  if command -v uv &> /dev/null; then
    echo "   Running uv sync in .cursor/ralph-dashboard ..."
    if (cd "$dash_dir" && uv sync --no-dev); then
      echo "✓ Ralph dashboard environment ready"
    else
      echo "   ⚠️  uv sync failed"
      return 1
    fi
    return 0
  fi

  echo "   ⚠️  uv not found; install https://docs.astral.sh/uv/ then run:"
  echo "      cd .cursor/ralph-dashboard && uv sync"
  if command -v python3 &> /dev/null; then
    echo "   Trying python3 -m venv + pip install textual (fallback)..."
    python3 -m venv "$dash_dir/.venv"
    if "$dash_dir/.venv/bin/pip" install -q textual; then
      echo "✓ Dashboard venv created with pip (fallback)"
    else
      echo "   ⚠️  pip install textual failed"
      return 1
    fi
  else
    echo "   ⚠️  python3 not found; install Python 3.11+ or uv, then retry."
    return 1
  fi
  return 0
}

echo ""
echo "📦 Ralph dashboard (isolated Textual environment)..."
setup_ralph_dashboard_env || true
echo ""

# =============================================================================
# INITIALIZE .ralph/ STATE
# =============================================================================

echo "📁 Initializing .ralph/ state directory..."

write_file_if_missing .ralph/guardrails.md << 'EOF'
# Ralph Guardrails (Signs)

> Lessons learned from past failures. READ THESE BEFORE ACTING.

## Core Signs

### Sign: Read Before Writing
- **Trigger**: Before modifying any file
- **Instruction**: Always read the existing file first
- **Added after**: Core principle

### Sign: Search Before Large Read
- **Trigger**: Before opening a large or unfamiliar file
- **Instruction**: Shortlist files with `rg --files | rg` or `find`, search inside them with `rg -n`, then read one bounded window with `sed -n`
- **Added after**: Core principle

### Sign: Test After Changes
- **Trigger**: After any code change
- **Instruction**: Run tests to verify nothing broke
- **Added after**: Core principle

### Sign: Verify Before Checkoff
- **Trigger**: Before marking any criterion complete
- **Instruction**: Run the verification command or confirm the concrete observable result first
- **Added after**: Core principle

### Sign: Commit Checkpoints
- **Trigger**: Before risky changes
- **Instruction**: Commit current working state first
- **Added after**: Core principle

### Sign: Leave a Precise Handoff
- **Trigger**: Before rotation or when blocked
- **Instruction**: Record the exact next command, file, symbol, or line window in `.ralph/progress.md`
- **Added after**: Core principle

---

## Learned Signs

(Signs added from observed failures will appear below)

EOF

write_file_if_missing .ralph/progress.md << 'EOF'
<!-- RALPH_COMPACT_KEEP_START -->
# Progress Log

> Updated by the agent after significant work.

- Keep the live summary concise and authoritative.
- Historical detail may be auto-rotated to `.ralph/archive/` during long runs.
<!-- RALPH_COMPACT_KEEP_END -->

---

## Session History

EOF

write_file_if_missing .ralph/errors.log << 'EOF'
# Error Log

> Failures detected by stream-parser. Use to update guardrails.

EOF

write_file_if_missing .ralph/activity.log << 'EOF'
# Activity Log

> Real-time tool call logging from stream-parser.

EOF

write_file_if_missing .ralph/signals.log << 'EOF'
# Signal Log

> Durable signal/event history for the Ralph dashboard.

EOF

write_file_if_missing .ralph/session-brief.md << 'EOF'
# Ralph Session Brief

> Auto-generated before each iteration. Read this first.

- Generated: not yet
- Criteria: 0 / 0 complete
- Next unchecked criterion: unknown
- Read strategy: open the relevant slice of `RALPH_TASK.md`, not the whole repo.
- Discovery strategy: shortlist files with `rg --files | rg` or `find`, then `rg -n`, then bounded `sed -n` windows.

EOF

write_file_if_missing .ralph/navigation-brief.md << 'EOF'
# Ralph Navigation Brief

> Auto-generated before each iteration when Ralph needs a tighter map through a large file.

- Generated: not yet
- Last session signal: NONE
- Forced narrow mode: standby
- Current hot file: not yet identified
- Search-first workflow: shortlist files, grep for task words, then read one bounded slice at a time.

EOF

write_file_if_missing .ralph/read-trace.tsv << 'EOF'
timestamp	iteration	path	bytes	lines	per_file_reads	write_calls_before_read	thrash_hit
EOF

write_file_if_missing .ralph/shell-edit-trace.tsv << 'EOF'
timestamp	iteration	exit_code	status	path	before_bytes	after_bytes	work_path	command
EOF

write_file_if_missing .ralph/runtime.env << 'EOF'
# Ralph runtime state
RALPH_RUNTIME_STATUS=idle
RALPH_RUNTIME_ITERATION=0
RALPH_RUNTIME_MODEL=auto
RALPH_RUNTIME_LAST_SIGNAL=NONE
RALPH_RUNTIME_LAST_EVENT=Waiting\ for\ Ralph
RALPH_RUNTIME_MODE=loop
RALPH_RUNTIME_AGENT_PID=''
RALPH_RUNTIME_UPDATED_AT=not\ yet
EOF

if [[ ! -f .ralph/.iteration ]]; then
  echo "0" > .ralph/.iteration
  echo "✓ Created .ralph/.iteration"
else
  echo "✓ Preserved .ralph/.iteration"
fi

echo "✓ .ralph/ upgrade complete"

# =============================================================================
# CREATE RALPH_TASK.md TEMPLATE
# =============================================================================

if [[ ! -f "RALPH_TASK.md" ]]; then
  echo "📝 Creating RALPH_TASK.md template..."
  cat > RALPH_TASK.md <<'TASKEOF'
---
task: Build a CLI todo app in TypeScript
test_command: "npx ts-node todo.ts list"
---

# Task: CLI Todo App (TypeScript)

Build a simple command-line todo application in TypeScript.

## Requirements

1. Single file: `todo.ts`
2. Uses `todos.json` for persistence
3. Three commands: add, list, done
4. TypeScript with proper types

## Success Criteria

1. [ ] `npx ts-node todo.ts add "Buy milk"` adds a todo and confirms
2. [ ] `npx ts-node todo.ts list` shows all todos with IDs and status
3. [ ] `npx ts-node todo.ts done 1` marks todo 1 as complete
4. [ ] Todos survive script restart (JSON persistence)
5. [ ] Invalid commands show helpful usage message
6. [ ] Code has proper TypeScript types (no `any`)

## Scaffolding Notes

- Ralph only tracks the checkbox list under `## Success Criteria`
- Keep each checkbox to one outcome you can verify with a command or observable result
- Put manual approval/browser/deploy steps in notes, not in the tracked checklist

## Example Output

```
$ npx ts-node todo.ts add "Buy milk"
✓ Added: "Buy milk" (id: 1)

$ npx ts-node todo.ts list
1. [ ] Buy milk

$ npx ts-node todo.ts done 1
✓ Completed: "Buy milk"
```

---

## Ralph Instructions

1. Work on the next incomplete criterion (marked [ ])
2. Check off completed criteria (change [ ] to [x])
3. Run tests after changes
4. Commit your changes frequently
5. If blocked, record the exact blocker and next command/path in `.ralph/progress.md`
6. When ALL criteria are [x], output: `<ralph>COMPLETE</ralph>`
7. If stuck on the same issue 3+ times, output: `<ralph>GUTTER</ralph>`
TASKEOF
  echo "✓ Created RALPH_TASK.md with example task"
else
  echo "✓ Preserved RALPH_TASK.md"
fi

# =============================================================================
# UPDATE .gitignore
# =============================================================================

if [[ -f ".gitignore" ]]; then
  if ! grep -q "ralph-config.json" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Ralph config (may contain API key)" >> .gitignore
    echo ".cursor/ralph-config.json" >> .gitignore
  fi
else
  cat > .gitignore <<'EOF'
# Ralph config (may contain API key)
.cursor/ralph-config.json
EOF
fi
echo "✓ Updated .gitignore"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ Ralph installed!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Files created:"
echo ""
echo "  📁 .cursor/ralph-scripts/"
echo "     ├── ralph-setup.sh          - Main entry (interactive)"
echo "     ├── ralph-loop.sh           - CLI mode (for scripting)"
echo "     ├── ralph-once.sh           - Single iteration (testing)"
echo "     └── ...                     - Other utilities"
echo ""
echo "  📁 .ralph/                     - State files (tracked in git)"
echo "     ├── guardrails.md           - Lessons learned"
echo "     ├── progress.md             - Progress log"
echo "     ├── activity.log            - Tool call log"
echo "     └── errors.log              - Failure log"
echo ""
echo "  📄 RALPH_TASK.md               - Your task definition (edit this!)"
echo ""
echo "Next steps:"
echo "  1. Edit RALPH_TASK.md to define your actual task"
echo "  2. Run: ./.cursor/ralph-scripts/ralph-setup.sh"
echo ""
echo "Alternative commands:"
echo "  • ralph-once.sh    - Test with single iteration first"
echo "  • ralph-loop.sh    - CLI mode with flags (for scripting)"
echo ""
echo "Monitor progress:"
echo "  tail -f .ralph/activity.log"
echo ""
echo "Learn more: https://ghuntley.com/ralph/"
echo "═══════════════════════════════════════════════════════════════════"
