# Design: Relative Time Badge for GitHub Dashboard

## Problem
The dashboard previously displayed a static UTC timestamp (`Last updated: YYYY-MM-DD HH:MM:SS UTC`). This timestamp was hardcoded into the `README.md` at generation time, making it difficult for users to quickly perceive the dashboard's "freshness" without mental calculation.

## Solution
Replace the static text with a dynamic Shields.io badge that leverages GitHub's commit metadata.

### Architecture
- **Source:** The `generate.sh` script now identifies the current repository via the `GITHUB_REPOSITORY` environment variable (falling back to `dachrisch/gh-dash`).
- **Badge:** Uses the Shields.io `last-commit` endpoint: `https://img.shields.io/github/last-commit/dachrisch/gh-dash?label=last%20updated&style=flat-square`.
- **Interactivity:** The badge is wrapped in a link to the repository's GitHub Action workflow runs for `update-dash.yml`, allowing users to inspect the update logs easily.

### Benefits
1. **Perceptual Freshness:** Displays relative time (e.g., "5 minutes ago"), which is more intuitive than a static UTC date.
2. **Automatic Updates:** Since the GitHub Action commits the updated `README.md` on every run, the "last commit" badge perfectly reflects the last successful dashboard update.
3. **Robustness:** Uses environment variables to remain portable across forks or renames.

### Implementation Details
Modified `generate.sh` to include:
```bash
repo_full_name="${GITHUB_REPOSITORY:-dachrisch/gh-dash}"
# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
[![last updated](https://img.shields.io/github/last-commit/${repo_full_name}?label=last%20updated&style=flat-square)](https://github.com/${repo_full_name}/actions/workflows/update-dash.yml)
...
EOF
```

## Verification
- **Local Run:** Verified that the badge markdown is correctly generated.
- **Style Consistency:** Maintained the `flat-square` style consistent with existing badges in the repo.
