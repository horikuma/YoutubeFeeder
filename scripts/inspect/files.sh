#!/usr/bin/env bash

ROOT="."

# thresholds
WARN=300
ERROR=600

small=0
medium=0
large=0

find "$ROOT" -name "*.swift" \
| while read -r file; do
  lines=$(wc -l < "$file")

  if [ "$lines" -ge "$ERROR" ]; then
    tag="[ERROR]"
    large=$((large+1))
  elif [ "$lines" -ge "$WARN" ]; then
    tag="[WARN ]"
    medium=$((medium+1))
  else
    tag="[ OK  ]"
    small=$((small+1))
  fi

  printf "%6d  %s  %s\n" "$lines" "$tag" "$file"
done | sort -nr

echo
printf "Summary: OK=%d WARN=%d ERROR=%d\n" "$small" "$medium" "$large"