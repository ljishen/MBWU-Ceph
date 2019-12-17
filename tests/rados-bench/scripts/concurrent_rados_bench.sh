#!/usr/bin/env bash

set -eu -o pipefail

# 3 = 1 (concurrency) + 2 (from rados_bench.sh)
if [[ "$#" -lt 3 ]]; then
  printf "usage: %s <concurrency> <options>

options: options for rados_bench.sh
"
  exit
fi

declare -a pids

die() {
  if [[ "${#pids[@]}" -eq 0 ]]; then
    return
  fi

  echo "Terminating all subprocesses..."
  for p in "${pids[@]}"; do
    if [[ -d "/proc/$p" ]]; then
      kill -s SIGTERM "$p"
    fi
  done
  echo "Done."
}
trap die EXIT

script_dir="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"

export APPEND_PID_TO_LOG_FILENAME=1

CONCURRENCY="$1"
shift

for i in $(seq 1 "$CONCURRENCY"); do
  "$script_dir"/rados_bench.sh "$@" > /dev/null &
  pids["$i"]=$!
  echo "Running rados bench $i with process ${pids[$i]}"
done

echo
wait

echo "All $CONCURRENCY rados bench processes are completed."
