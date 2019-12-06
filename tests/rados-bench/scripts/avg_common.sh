#!/usr/bin/env bash

set -eu -o pipefail

function usage() {
  printf "usage: %s <file_pattern> [last_num_entries]

file_pattern\\t\\t: find the files in which the last number of entries will be be calculated.
            \\t\\t  this parameter should be quoted in any case.
last_num_entries\\t: calculate the average value for the last number of entries (default 30).
" "${BASH_SOURCE[0]}"
  exit 0
}

if [[ "$#" -lt 1 ]]; then
  usage
fi

PATTERN="$1"
dir=$(dirname "$PATTERN")
name=$(basename "$PATTERN")
export dir name

### select awk
[[ -x /usr/bin/mawk ]] && awk='mawk -W interactive' || awk=awk
export awk

last_num_entries="${2:-30}"
if ! [[ "$last_num_entries" =~ ^[0-9]+$ ]]; then
  echo >&2 "[ERROR] **last_num_entries** can only be a number."
  exit 1
fi

echo -e "\033[0;32m[INFO] Calculate the average value for the last $last_num_entries entries:\033[0m"
