#!/usr/bin/env bash

set -eu -o pipefail

function usage() {
  printf "usage: %s <threads> [objsizes]

threads\\t\\t: number of simulated threads.
objsizes\\t: the list of object sizes under test.
        \\t  The default object size list is (\"4K\" \"16K\" \"64K\" \"256K\" \"1M\" \"4M\")

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
shift

DEFAULT_OBJ_SIZES=("4K" "16K" "64K" "256K" "1M" "4M")
objsizes=("${DEFAULT_OBJ_SIZES[@]}")
if [[ "$#" -gt 0 ]]; then
  objsizes=("$@")
fi
echo -e "\033[0;32m[INFO] Loop for object sizes: ${objsizes[*]}\033[0m"

BENCH_SECONDS=120
POOL_NAME=rados

function exec_bench() {
  # The mode can be write, seq, or rand. seq and rand are
  # read benchmarks, either sequential or random.
  # See https://docs.ceph.com/docs/master/man/8/rados/?highlight=bench
  local mode="$1" objidx="$2" run_name="$3"
  shift 3
  local comm=("$@")

  local objsize="${objsizes[objidx]}" script_dir

  script_dir="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"

  local log_file="$script_dir"/../results/"$mode"_"$objsize"obj_"$threads"threads.log
  local comm_str="[COMMAND ($((objidx + 1))/${#objsizes[@]}), $mode] ${comm[*]}"

  echo -e "\033[0;32m$comm_str\033[0m"
  echo "$comm_str" > "$log_file"
  echo "[INFO] run name: $run_name (useful for further cleanup or read)" | tee -a "$log_file"
  eval "${comm[*]}" | tee -a "$log_file"

  echo
}

for idx in "${!objsizes[@]}"; do
  objsize="${objsizes[idx]}"
  run_name="$objsize"obj_"$threads"threads_"$$"

  mode=write

  # specify run-name for further cleanup or read
  write_comm=(
    rados bench
    -p "$POOL_NAME"
    "$BENCH_SECONDS"
    "$mode"
    -b "$objsize"
    -t "$threads"
    --show-time
    --write-object
    --no-hints
    --no-cleanup
    --run-name "$run_name"
  )

  exec_bench "$mode" "$idx" "$run_name" "${write_comm[@]}"

  mode=seq
  read_comm=(
    rados bench
    -p "$POOL_NAME"
    "$BENCH_SECONDS"
    "$mode"
    -t "$threads"
    --show-time
    --no-verify
    --run-name "$run_name"
  )

  exec_bench "$mode" "$idx" "$run_name" "${read_comm[@]}"
done
