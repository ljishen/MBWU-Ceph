#!/usr/bin/env bash

set -eu -o pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: ${BASH_SOURCE[0]} <concurrency>"
  exit
fi

CONCURRENCY="$1"

declare -a pids

die() {
  if [[ "${#pids[@]}" -eq 0 ]]; then
    return
  fi

  echo "Terminating all subprocesses..."
  for p in "${pids[@]}"; do
    if [[ -f "/proc/$p" ]]; then
      kill -s SIGTERM "$p"
    fi
  done
  echo "Done."
}
trap die EXIT

script_dir="$(cd "$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")" > /dev/null 2>&1 && pwd)"

export APPEND_PID_TO_LOG_FILENAME=1

for i in $(seq 1 "$CONCURRENCY"); do
  "$script_dir"/rados_bench.sh 1 120 4M > /dev/null &
  pids["$i"]=$!
  echo "Running rados bench $i with process ${pids[$i]}"
done

echo
wait

echo "All $CONCURRENCY rados bench processes are completed."
