#!/usr/bin/env bash
set -euo pipefail

# Helper to abbreviate "45 minutes ago" -> "45m"
abbreviate() {
  echo "$1" | sed -E 's/ seconds? ago/s/; s/ minutes? ago/m/; s/ hours? ago/h/; s/ days? ago/d/; s/ weeks? ago/w/; s/ months? ago/mo/; s/ years? ago/y/'
}

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

  # 1. Fetch CI Status and check for details
  ci_json=$(gh api repos/$name/commits/$branch/status 2>/dev/null || echo "{}")
  ci_state=$(echo "$ci_json" | jq -r '.state // "unknown"')
  
  failed_ctx=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "failure") | .context' | head -n 1)
  failed_url=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "failure") | .target_url' | head -n 1)
  
  hold_ctx=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "pending" and (.context | contains("hold"))) | .context' | head -n 1)
  hold_url=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "pending" and (.context | contains("hold"))) | .target_url' | head -n 1)

  # 2. Fetch PRs and check for conflicts/age
  pr_count=$(gh pr list --repo "$name" --state open --json number --limit 100 2>/dev/null | jq 'length')
  pr_age_human=$(gh pr list --repo "$name" --state all --limit 1 --json createdAt --template '{{range .}}{{timeago .createdAt}}{{end}}' 2>/dev/null || echo "")
  pr_age_short=$(abbreviate "$pr_age_human")
  conflicts_url=$(gh pr list --repo "$name" --state open --json url,mergeable 2>/dev/null | jq -r '.[] | select(.mergeable == "CONFLICTING") | .url' | head -n 1)

  # 3. Fetch Tag age
  tag_age_human=$(gh release list --repo "$name" --limit 1 --json createdAt --template '{{range .}}{{timeago .createdAt}}{{end}}' 2>/dev/null || echo "")
  tag_age_short=$(abbreviate "$tag_age_human")

  # 4. Fetch Commit age
  commit_age_human=$(gh repo view "$name" --json pushedAt --template '{{timeago .pushedAt}}' 2>/dev/null || echo "")
  commit_age_short=$(abbreviate "$commit_age_human")

  # 5. Compute Action Link
  action_label=""
  action_url=""

  if [ -n "$failed_ctx" ]; then
    short_ctx=$(echo "$failed_ctx" | sed 's#ci/circleci: ##; s#build_test_deploy/##')
    action_label="FIX $short_ctx"
    action_url="${failed_url:-$url/actions}"
  elif [ -n "$conflicts_url" ]; then
    action_label="RESOLVE CONFLICTS"
    action_url="$conflicts_url"
  elif [ -n "$hold_ctx" ]; then
    short_ctx=$(echo "$hold_ctx" | sed 's#ci/circleci: ##; s#build_test_deploy/##')
    action_label="APPROVE $short_ctx"
    action_url="${hold_url:-https://app.circleci.com/pipelines/github/$name}"
  elif [ "$ci_state" == "pending" ]; then
    action_label="VIEW PROGRESS"
    action_url="$url/actions"
  elif [ "$pr_count" -gt 0 ]; then
    action_label="REVIEW PRS"
    action_url="$url/pulls"
  else
    action_label="ALL DONE"
    action_url="$url"
  fi

  # Start new row every 3 items
  if [ $((i % 3)) -eq 0 ]; then
    [ $i -gt 0 ] && echo "  </tr>"
    echo "  <tr>"
  fi

  # Badges
  tag_badge="https://img.shields.io/github/v/release/$name?label=tag&style=flat-square&color=blue"
  pr_badge="https://img.shields.io/github/issues-pr/$name?label=prs&style=flat-square"
  
  # Custom age badges
  commit_age_badge="https://img.shields.io/badge/commit-${commit_age_short// /%20}-green?style=flat-square"
  pr_age_badge="https://img.shields.io/badge/${pr_age_short// /%20}-gray?style=flat-square"
  tag_age_badge="https://img.shields.io/badge/${tag_age_short// /%20}-gray?style=flat-square"

  # Output Card
  cat <<CARD
    <td width="33%" align="left" valign="top" style="border: 1px solid #30363d; border-radius: 6px; padding: 12px;">
      <a href="$url"><b>$name</b></a><br>
      <hr style="border: 0; border-top: 1px solid #30363d; margin: 8px 0;">
      <p style="margin: 12px 0;">
        <a href="$action_url">
          <img src="https://img.shields.io/badge/ACTION-$action_label-orange?style=for-the-badge" alt="action">
        </a>
      </p>
      <div style="margin-top: 10px;">
        <a href="$url/commits/$branch"><img src="$commit_age_badge" alt="commit"></a> ✳️ <a href="$url/pulls"><img src="$pr_badge" alt="prs"></a>$([ -n "$pr_age_short" ] && echo " <img src=\"$pr_age_badge\" alt=\"pr-age\">")<br>
        <a href="$url/releases"><img src="$tag_badge" alt="tag"></a>$([ -n "$tag_age_short" ] && echo " <img src=\"$tag_age_badge\" alt=\"tag-age\">")
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
