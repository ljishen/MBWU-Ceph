#!/usr/bin/env bash

set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR"/avg_common.sh

files=($(find "$dir" -maxdepth 1 -type f -name "$name" ! -name '*.network'))

if [[ "${#files[@]}" -eq 0 ]]; then
  echo >&2 "[ERROR] No files found for this pattern."
  exit 1
fi

declare awk
for file in "${files[@]}"; do
  $awk -v num_entries="${last_num_entries:?}" '
    function calc(nums) {
        # ignore the last record because it is not correct mostly
        start = count - 2
        end = count - num_entries < 0 ? 0 : count - num_entries
        calc_size = start - end + 1

        sum = 0
        for (idx = start; idx >= end; idx--) {
            sum += nums[idx]
        }

        avg = sum / calc_size

        sum_diff_square = 0
        for (idx = start; idx >= end; idx--) {
            diff = avg - nums[idx]
            sum_diff_square += (diff * diff)
        }

        std = sqrt(sum_diff_square / calc_size)
        return "avg: " avg " MB/s, std: " std \
            (count < num_entries ? " (warning: less than " num_entries " entries [" count "])" : "")
    }


    BEGIN { count = 0 }

    $3 ~ /^[0-9.]+$/ && $8 ~ /^[0-9.]+$/ {
        if ($3 > 0 && $8 != 0)
            nums[count++] = $8
    }

    END {
        n = split(ARGV[1], arr, "/")
        filename = arr[n]
        print filename, "=>", calc(nums)
    }
' "$file"
done
