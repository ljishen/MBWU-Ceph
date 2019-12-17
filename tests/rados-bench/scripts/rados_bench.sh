#!/usr/bin/env bash

set -eu -o pipefail

DEFAULT_OBJ_SIZES=("4K" "16K" "64K" "256K" "1M" "4M")

usage() {
  printf "usage: %s <threads> <seconds> [options]

threads\\t: number of simulated threads.
seconds\\t: benchmark duration in seconds.
options\\t: additional options for rados bench.
       \\t  See https://docs.ceph.com/docs/master/man/8/rados/?highlight=bench


RADOS_BENCH_OBJ_SIZES
    If this variable exists, then we will use the list of object sizes instead
    of the default size list (%s).
    For example,
        RADOS_BENCH_OBJ_SIZES=\"32K 128K\"

APPEND_PID_TO_LOG_FILENAME
    If this variable exists and its value is 1, then we will append pid to the
    log filename.
    This option helps to separate the log files if multiple instances are
    run simultaneously.

NOTE: Make sure you have a Ceph pool named 'rados'.
" "${BASH_SOURCE[0]}" "${DEFAULT_OBJ_SIZES[*]}"
  exit 0
}

if [[ "$#" -lt 2 ]]; then
  usage
fi

RE_NUM='^[0-9]+$'

threads="$1"
if ! [[ "$threads" =~ $RE_NUM ]]; then
  echo >&2 "[ERROR] **threads** ($threads) is NOT a number."
  exit 1
fi

bench_seconds="$2"
if ! [[ "$bench_seconds" =~ $RE_NUM ]]; then
  echo >&2 "[ERROR] **bench_seconds** ($bench_seconds) is NOT a number."
  exit 1
fi

shift 2

if [[ -z "${RADOS_BENCH_OBJ_SIZES:-}" ]]; then
  objsizes=("${DEFAULT_OBJ_SIZES[@]}")
else
  IFS=', ' read -r -a objsizes <<< "$RADOS_BENCH_OBJ_SIZES"
fi
echo -e "\033[0;32m[INFO] Loop for object sizes: ${objsizes[*]}\033[0m"

POOL_NAME=rados
PERF_STAT_NETWORK_PID_FILE=/tmp/mbwu-ceph/network_log_"$$".pid

start_perf_logging() {
  local associated_log_file="$1"
  local interval_in_seconds=1

  # use the ISO 8601 format (YYYY-MM-DD) to print the date for
  # the following perf command (e.g., sar)
  export S_TIME_FORMAT=ISO

  local network_log_file="$associated_log_file".network
  echo "[INFO] start network throughput logging to file $network_log_file" | tee -a "$associated_log_file"
  nohup stdbuf -oL -eL sar -n DEV "$interval_in_seconds" < /dev/null > "$network_log_file" 2>&1 &
  mkdir -p "$(dirname "$PERF_STAT_NETWORK_PID_FILE")"
  echo $! > "$PERF_STAT_NETWORK_PID_FILE"
}

stop_perf_logging() {
  if [[ -f "$PERF_STAT_NETWORK_PID_FILE" ]]; then
    if [[ "$#" -gt 0 ]]; then
      echo "[INFO] stop network throughput logging" | tee -a "$1"
    fi
    pkill --signal SIGINT --pidfile "$PERF_STAT_NETWORK_PID_FILE"
    rm -f "$PERF_STAT_NETWORK_PID_FILE"
  fi
}
trap stop_perf_logging EXIT

exec_bench() {
  # The mode can be write, seq, or rand. seq and rand are
  # read benchmarks, either sequential or random.
  # See https://docs.ceph.com/docs/master/man/8/rados/?highlight=bench
  local mode="$1" objidx="$2" run_name="$3"
  shift 3
  local comm=("$@")

  local objsize="${objsizes[objidx]}" script_dir

  script_dir="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"

  local log_file log_file_suffix
  if [[ "1" == "${APPEND_PID_TO_LOG_FILENAME:-}" ]]; then
    log_file_suffix=_"$$"
  fi
  log_file="$script_dir"/../results/"$mode"_"$objsize"obj_"$threads"threads"${log_file_suffix:-}".log

  local comm_str="[COMMAND ($((objidx + 1))/${#objsizes[@]}), $mode] ${comm[*]}"

  echo -e "\033[0;32m$comm_str\033[0m"
  echo "$comm_str" > "$log_file"
  echo "[INFO] run name: $run_name (useful for further cleanup or read)" | tee -a "$log_file"

  start_perf_logging "$log_file"
  eval "${comm[*]}" | tee -a "$log_file"
  stop_perf_logging "$log_file"

  echo "[INFO] log file is saved to $log_file"

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
    "$bench_seconds"
    "$mode"
    -b "$objsize"
    -t "$threads"
    --show-time
    --write-object
    --no-hints
    --no-cleanup
    --run-name "$run_name"
    "$@"
  )

  exec_bench "$mode" "$idx" "$run_name" "${write_comm[@]}"

  mode=seq
  read_comm=(
    rados bench
    -p "$POOL_NAME"
    "$bench_seconds"
    "$mode"
    -t "$threads"
    --show-time
    --no-verify
    --run-name "$run_name"
    "$@"
  )

  exec_bench "$mode" "$idx" "$run_name" "${read_comm[@]}"
done
