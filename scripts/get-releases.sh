#!/bin/bash

set -e

REPO_OWNER="${REPO_OWNER:-TheBigEye}"
REPO_NAME="${REPO_NAME:-llama-cpp-python-cpu}"

# API endpoint de GitHub
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases"

if [ -n "$GITHUB_TOKEN" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
  AUTH_HEADER=()
fi

all_releases="[]"
page=1
per_page=100

while true; do
  response=$(curl -s "${AUTH_HEADER[@]}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${API_URL}?per_page=${per_page}&page=${page}")
  
  release_count=$(echo "$response" | jq '. | length')
  
  if [ "$release_count" -eq 0 ]; then
    break
  fi
  
  all_releases=$(echo "$all_releases" "$response" | jq -s 'add')
  
  if [ "$release_count" -lt "$per_page" ]; then
    break
  fi
  
  page=$((page + 1))
done

echo "$all_releases" | jq '[.[] | {
  tag_name: .tag_name,
  name: .name,
  created_at: .created_at,
  assets: [.assets[] | {
    name: .name,
    browser_download_url: .browser_download_url,
    size: .size
  }]
}]'
