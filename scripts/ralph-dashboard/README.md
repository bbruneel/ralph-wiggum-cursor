# Ralph dashboard (nested uv)

This directory is a **standalone uv project** for the Textual dashboard. It does not use your repository’s root `pyproject.toml`.

## Install or refresh (pinned lockfile)

```bash
uv sync
```

## Float to latest compatible versions (power users)

The `uv.lock` file pins dependencies for reproducible installs. To resolve newer versions allowed by `pyproject.toml`, then install them:

```bash
uv lock --upgrade && uv sync
```

Re-run the Ralph installer later to pick up an updated lockfile from upstream if you want to return to the project’s pinned defaults.
