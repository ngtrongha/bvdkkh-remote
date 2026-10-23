#!/usr/bin/env bash
# Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
# Project: BVĐKKH - Remote
# Author: Nguyễn Trọng Hà
set -euo pipefail

tag=${1:?Release tag required}
base=${2:-}
output=${3:-release_notes.md}
limit=30
range=HEAD

if [[ -n "$base" ]] && git merge-base --is-ancestor "$base" HEAD 2>/dev/null; then
  range="$base..HEAD"
else
  echo "[WARN] No valid previous build; limiting notes to $limit recent commits." >&2
fi

{
  printf '## Có gì mới trong phiên bản %s\n\n' "$tag"
  notes=$(git log "$range" --no-merges -n "$limit" --pretty=format:'* %s (%h)')
  if [[ -n "$notes" ]]; then
    printf '%s\n\n' "$notes"
    printf '_Hiển thị tối đa %s thay đổi kể từ bản dựng thành công trước._\n' "$limit"
  else
    printf 'Bản dựng lại; không có thay đổi mã nguồn kể từ lần build thành công trước.\n'
  fi
  printf '\n---\n### Thông tin bản dựng & Cài đặt\n'
  printf '%s\n' '- **Kênh phát hành:** [bvdkkh-remote-release](https://github.com/ngtrongha/bvdkkh-remote-release)'
} > "$output"
