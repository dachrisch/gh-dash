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
  
  echo "Processing repository: $name (branch: $branch)" >&2

  # 1. Fetch CI Status and check for 'hold'
  ci_json=$(gh api repos/$name/commits/$branch/status 2>/dev/null || echo "{}")
  ci_state=$(echo "$ci_json" | jq -r '.state // "unknown"')
  has_hold=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "pending" and (.context | contains("hold"))) | .context' | head -n 1)
  
  # 2. Fetch PRs and check for conflicts
  pr_json=$(gh pr list --repo "$name" --state open --json number,url,mergeable 2>/dev/null || echo "[]")
  pr_count=$(echo "$pr_json" | jq 'length')
  conflicts=$(echo "$pr_json" | jq -r '.[] | select(.mergeable == "CONFLICTING") | .url' | head -n 1)

  # 3. Compute Health Indicator and Action Link
  action_label=""
  action_url=""

  if [ "$ci_state" == "failure" ]; then
    health="🔴 **FAILED**"
    action_label="Fix CI"
    action_url="$url/actions"
  elif [ -n "$conflicts" ]; then
    health="🔴 **CONFLICT**"
    action_label="Resolve Conflicts"
    action_url="$conflicts"
  elif [ -n "$has_hold" ]; then
    health="🟣 **ON HOLD**"
    action_label="Approve Deployment"
    action_url="https://app.circleci.com/pipelines/github/$name"
  elif [ "$ci_state" == "pending" ]; then
    health="🟡 **BUILDING**"
    action_label="View Progress"
    action_url="$url/actions"
  elif [ "$pr_count" -gt 0 ]; then
    health="🔵 **ACTIVE**"
    action_label="Review PRs"
    action_url="$url/pulls"
  else
    health="🟢 **CLEAN**"
    action_label="Repo Home"
    action_url="$url"
  fi

  # Start new row every 3 items
  if [ $((i % 3)) -eq 0 ]; then
    [ $i -gt 0 ] && echo "  </tr>"
    echo "  <tr>"
  fi

  # Badges for specific metadata
  tag_badge="https://img.shields.io/github/v/release/$name?label=tag&style=flat-square&color=blue"
  commit_badge="https://img.shields.io/github/last-commit/$name?label=commit&style=flat-square&color=green"

  # Output Card
  cat <<CARD
    <td width="33%" align="left" valign="top" style="border: 1px solid #30363d; border-radius: 6px; padding: 12px;">
      <a href="$url"><b>$name</b></a><br>
      <hr style="border: 0; border-top: 1px solid #30363d; margin: 8px 0;">
      <p style="margin: 4px 0;">Health: $health</p>
      <p style="margin: 4px 0;">PRs: ⚓ $pr_count</p>
      <p style="margin: 12px 0;">
        <a href="$action_url">
          <img src="https://img.shields.io/badge/ACTION-$action_label-orange?style=for-the-badge" alt="action">
        </a>
      </p>
      <div style="margin-top: 10px;">
        <img src="$tag_badge" alt="tag">
        <img src="$commit_badge" alt="commit">
      </div>
    </td>
CARD

  i=$((i + 1))
done

# Fill remaining cells
while [ $((i % 3)) -ne 0 ]; do
  echo "    <td width=\"33%\"></td>"
  i=$((i + 1))
done

echo "  </tr>"
echo "</table>"

# Fill remaining cells
while [ $((i % 3)) -ne 0 ]; do
  echo "    <td width=\"33%\"></td>"
  i=$((i + 1))
done

echo "  </tr>"
echo "</table>"
