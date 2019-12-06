#!/usr/bin/env bash

set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR"/avg_common.sh

files=($(find "$dir" -maxdepth 1 -type f -name "$name" | grep ".network"))

if [[ "${#files[@]}" -eq 0 ]]; then
  echo >&2 "[ERROR] No files found for this pattern."
  exit 1
fi

declare awk
for file in "${files[@]}"; do
  $awk -v num_entries="${last_num_entries:?}" '
    BEGIN { empty_lines = 0 }

    NF == 0 { empty_lines++ }

    $1 ~ /^[0-9:]+$/ && $3 != "IFACE" {
        block = empty_lines - 1
        throughputs[$3, "rxkB", block] = $6
        throughputs[$3, "txkB", block] = $7
    }

    END {
        for (tp in throughputs) {
            split(tp, comp, SUBSEP)
            iface = comp[1]
            xxkB = comp[2]
            idx = comp[3]

            if (idx == 0 || idx == block)
                continue

            sum[iface, xxkB] += throughputs[iface, xxkB, idx]
        }

        n = split(ARGV[1], arr, "/")
        filename = arr[n]
        printf "==== %s ====\n", filename

        for (s in sum) {
            split(s, comp, SUBSEP)
            iface = comp[1]
            xxkB = comp[2]

            printf "%s, %s => %.2f MiB/s\n", iface, xxkB, sum[iface, xxkB] / (block - 1) / 1024
        }

        printf "========================\n"
    }
' "$file"
done
