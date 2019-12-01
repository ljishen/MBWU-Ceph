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
files=($(find . -type f -name "$PATTERN"))

if [[ "${#files[@]}" -eq 0 ]]; then
  echo >&2 "[ERROR] No files found for this pattern."
  exit 1
fi

### select awk
[[ -x /usr/bin/mawk ]] && awk='mawk -W interactive' || awk=awk

last_num_entries="${2:-30}"
if ! [[ "$last_num_entries" =~ ^[0-9]+$ ]]; then
  echo >&2 "[ERROR] **last_num_entries** can only be a number."
  exit 1
fi

echo -e "\033[0;32m[INFO] Calculate the average value for the last $last_num_entries entries:\033[0m"

for file in "${files[@]}"; do
  $awk -v num_entries="$last_num_entries" '
    function calc(nums) {
        if (count < num_entries)
            return "less than " num_entries " entries found"

        sum = 0

        for (idx = count - 1; idx >= count - num_entries; idx--) {
            sum += nums[idx]
        }

        avg = sum / num_entries

        sum_diff_square = 0
        for (idx = count - 1; idx >= count - num_entries; idx--) {
            diff = avg - nums[idx]
            sum_diff_square += (diff * diff)
        }

        std = sqrt(sum_diff_square / num_entries)
        return "avg: " avg " MB/s, std: " std
    }


    BEGIN { count = 0 }

    $3 ~ /^[0-9.]+$/ && $8 ~ /^[0-9.]+$/ {
        if ($3 > 0 && $8 != 0)
            nums[count++] = $8
    }

    END { print ARGV[1], "=>", calc(nums) }
' "$file"
done
