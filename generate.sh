#!/usr/bin/env bash
set -euo pipefail

# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

<table width="100%">
EOF

# Fetch repos with topic gh-dash
echo "Searching for repositories with topic 'gh-dash'..." >&2
repos=$(gh repo list --topic gh-dash --json nameWithOwner,url,defaultBranchRef --limit 100)
count=$(echo "$repos" | jq 'length')
echo "Found $count repositories." >&2

i=0
echo "$repos" | jq -c '.[]' | while read -r repo; do
  name=$(echo "$repo" | jq -r '.nameWithOwner')
  url=$(echo "$repo" | jq -r '.url')
  branch=$(echo "$repo" | jq -r '.defaultBranchRef.name // "main"')
  
  # Start new row every 3 items
  if [ $((i % 3)) -eq 0 ]; then
    [ $i -gt 0 ] && echo "  </tr>"
    echo "  <tr>"
  fi

  echo "Processing repository: $name (branch: $branch)" >&2

  # Shields.io Badges
  status_badge="https://img.shields.io/github/checks-status/$name/$branch?label=status"
  pr_badge="https://img.shields.io/github/issues-pr/$name?label=prs"
  rel_badge="https://img.shields.io/github/v/release/$name?label=tag&sort=semver"
  commit_badge="https://img.shields.io/github/last-commit/$name?label="
  reldate_badge="https://img.shields.io/github/release-date/$name?label="
  sec_badge="https://img.shields.io/github/code-scanning/alerts/$name?label="

  # Output Card (Table Cell)
  cat <<CARD
    <td width="33%" align="center" valign="top">
      <h4><a href="$url">$name</a></h4>
      <img src="$status_badge" alt="status"><br>
      <img src="$pr_badge" alt="prs"> <img src="$rel_badge" alt="release"><br>
      <img src="$commit_badge" alt="last-commit"><br>
      <img src="$reldate_badge" alt="release-date"><br>
      <img src="$sec_badge" alt="security">
    </td>
CARD

  i=$((i + 1))
done

# Close table
echo "  </tr>"
echo "</table>"
