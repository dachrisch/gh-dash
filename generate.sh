#!/usr/bin/env bash
set -euo pipefail

# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

| Repository | Status | PRs | Release | Commit | Released | Security |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
EOF

# Fetch repos with topic gh-dash
echo "Searching for repositories with topic 'gh-dash'..." >&2
repos=$(gh repo list --topic gh-dash --json nameWithOwner,url,defaultBranchRef --limit 100)
count=$(echo "$repos" | jq 'length')
echo "Found $count repositories." >&2

echo "$repos" | jq -c '.[]' | while read -r repo; do
  name=$(echo "$repo" | jq -r '.nameWithOwner')
  url=$(echo "$repo" | jq -r '.url')
  branch=$(echo "$repo" | jq -r '.defaultBranchRef.name // "main"')
  
  echo "Processing repository: $name (branch: $branch)" >&2

  # Shields.io Badges
  # Status: Combined Checks Status
  status_badge="![Status](https://img.shields.io/github/checks-status/$name/$branch?label=status)"
  
  # PRs: Open PRs count
  pr_badge="![PRs](https://img.shields.io/github/issues-pr/$name?label=prs)"
  
  # Release: Latest Release tag
  rel_badge="![Release](https://img.shields.io/github/v/release/$name?label=tag&sort=semver)"

  # Last Commit: Relative time
  commit_badge="![Last Commit](https://img.shields.io/github/last-commit/$name?label=)"

  # Release Date: Date of last release
  reldate_badge="![Release Date](https://img.shields.io/github/release-date/$name?label=)"

  # Security: Code scanning alerts (requires setup in the repo)
  sec_badge="![Security](https://img.shields.io/github/code-scanning/alerts/$name?label=)"

  # Output Table Row
  echo "| [$name]($url) | $status_badge | $pr_badge | $rel_badge | $commit_badge | $reldate_badge | $sec_badge |"
done
