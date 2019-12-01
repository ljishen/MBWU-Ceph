#!/usr/bin/env bash

set -eu -o pipefail

function usage() {
  printf "usage: %s <threads>

threads: number of simulated threads.

NOTE: Make sure you have a Ceph pool named 'rados'.
" "${BASH_SOURCE[0]}"
  exit 0
}

if [[ "$#" -lt 1 ]]; then
  usage
fi

threads="$1"
if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] **threads** can only be a number."
  exit 1
fi

BENCH_SECONDS=120
POOL_NAME=rados

OBJ_SIZES=("4K" "16K" "64K" "256K" "1M" "4M")

for idx in "${!OBJ_SIZES[@]}"; do
  size="${OBJ_SIZES[idx]}"

  # specify run-name for further cleanup or read
  comm=(
    rados bench
    -p "$POOL_NAME"
    "$BENCH_SECONDS"
    write
    -b "$size"
    -t "$threads"
    --show-time
    --write-object
    --no-verify
    --no-hints
    --no-cleanup
    --run-name write_"$size"obj_"$threads"threads
  )

  log_file=write_"$size"obj_"$threads"threads.log
  comm_str="[COMMAND ($((idx + 1))/${#OBJ_SIZES[@]})] ${comm[*]}"

  echo -e "\033[0;32m$comm_str\033[0m"
  echo "$comm_str" > "$log_file"
  eval "${comm[*]}" | tee -a "$log_file"

  echo
done
