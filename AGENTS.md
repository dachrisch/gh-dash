# AGENTS.md

## What this repo is

`gh-dash` publishes an auto-generated dashboard as the repository's `README.md`:
a table of cards for every repository carrying the `gh-dash` topic across the
owner's account, their organizations, and `bumbleflies`. Each card shows CI
status, open PRs, latest release and commit freshness as Shields.io badges,
plus one "next action" badge.

There is no application code, package manager or test suite. The repo is
effectively three files: the generator, its generated output, and the workflow
that keeps that output fresh.

## Layout

- `generate.sh` — Bash generator; writes the dashboard markdown to stdout.
- `README.md` — **generated output**, overwritten by `generate.sh`.
- `.github/workflows/update-dash.yml` — hourly workflow that runs the generator
  and commits `README.md` back to the default branch.
- `renovate.json` — Renovate config (`config:recommended`).
- `docs/plans/` — historical design notes, not active instructions.

This is a small, flat repo: there are no subdirectory-specific AGENTS.md guides.

## Build / verify

No build or test harness exists. Useful checks:

- `bash -n generate.sh` — syntax-check the generator.
- `./generate.sh > /tmp/dash.md` — regenerate locally. Needs `bash`, `jq`,
  `sed` and an authenticated `gh` CLI (`GH_TOKEN` or `GITHUB_TOKEN`) with access
  to the target accounts/organizations. `GITHUB_REPOSITORY` and
  `GITHUB_REPOSITORY_OWNER` control which account the badge/links point at;
  `--security` adds security-alert badges.
- Diff the generated output against the current `README.md` to review a change.

## Safety / conventions

- Do not hand-edit `README.md` — it is generated output and the hourly workflow
  will overwrite it. Put content changes in `generate.sh` and verify by
  regenerating.
- Never commit tokens or credentials. CI injects `GH_DASH_TOKEN` / `GITHUB_TOKEN`
  as Actions secrets; local runs use your own `gh` authentication.
- Keep changes minimal: editing the generator changes the dashboard for every
  tagged repository. Avoid altering the hourly commit loop or Renovate behavior
  unless that is the explicit task.
- Do not push directly to the default branch; work on a branch and open a PR.
