#!/usr/bin/env bash
set -euo pipefail

# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

<table border="0" width="100%">
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

  # Shields.io Badges (Style: flat)
  # 1. Status
  status_badge="https://img.shields.io/github/checks-status/$name/$branch?style=flat"
  # 2. PRs
  pr_badge="https://img.shields.io/github/issues-pr/$name?label=prs&style=flat"
  # 3. Release Tag
  rel_badge="https://img.shields.io/github/v/release/$name?label=tag&style=flat&sort=semver"
  # 4. Last Commit (Label-less for "today" look)
  commit_badge="https://img.shields.io/github/last-commit/$name?label=&style=flat&color=green"
  # 5. Release Date (Label-less for "today" look)
  reldate_badge="https://img.shields.io/github/release-date/$name?label=&style=flat&color=green"
  # 6. Security Alerts
  sec_badge="https://img.shields.io/github/code-scanning/alerts/$name?label=security&style=flat"

  # Output Card (Table Cell with internal padding and styling)
  cat <<CARD
    <td width="33%" align="center" style="border: 1px solid #30363d; border-radius: 6px; padding: 16px;">
      <div align="center">
        <h3><a href="$url">$name</a></h3>
        <p>
          <img src="$status_badge" alt="status">
        </p>
        <p>
          <img src="$pr_badge" alt="prs"> <img src="$rel_badge" alt="tag">
        </p>
        <p>
          <img src="$commit_badge" alt="last-commit"><br>
          <img src="$reldate_badge" alt="release-date">
        </p>
        <p>
          <img src="$sec_badge" alt="security">
        </p>
      </div>
    </td>
CARD

  i=$((i + 1))
done

# Fill remaining cells in the row if any
while [ $((i % 3)) -ne 0 ]; do
  echo "    <td width=\"33%\"></td>"
  i=$((i + 1))
done

# Close table
echo "  </tr>"
echo "</table>"
