# AGENTS.md

## Scope
- Repo is primarily bash (`scripts/`) plus Python TUI (`scripts/ralph-tui.py`).
- Keep changes focused, minimal, and aligned with existing script style.

## Core rules
- Follow TDD when practical: add/update tests first, then implement.
- Prefer latest stable dependencies unless they cause risky/complex refactors.
- Logging must be human-readable, concise, and actionable.

## Python and dependencies
- Use `uv` for Python workflows.
- Treat `pyproject.toml` as dependency source of truth.
- Manage deps with `uv add` / `uv remove`.
- Keep Python deps pip-installable in standard environments.

## Test and commit gates (required)
- Always run relevant unit tests before commit; do not commit on failures.
- Run `scripts/test-dashboard-smoke.sh` when touching dashboard/parser-related
  code (for example `scripts/ralph-tui.py`, `scripts/stream-parser.sh`).
- Run `scripts/test-installer-upgrade-smoke.sh` when touching installer/setup
  flows (for example `install.sh`, bootstrap/upgrade logic).
- Target >=80% coverage for changed Python modules/files when tooling exists.

## Example commands
- `uv add textual`
- `uv remove textual`
- `uv sync`
- `uv run pytest`
- `uv run pytest --cov --cov-report=term-missing`

## PR checklist
- [ ] Tests relevant to touched files were run and passed.
- [ ] Required smoke test(s) were run for touched areas.
- [ ] Coverage for changed Python modules/files is >=80% (or exception noted).
- [ ] New/changed logs are human-readable and actionable.
- [ ] Python dependency changes use `uv` and update `pyproject.toml`.
