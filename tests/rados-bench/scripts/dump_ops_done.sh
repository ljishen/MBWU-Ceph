#!/usr/bin/env bash

set -eu -o pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: ${BASH_SOURCE[0]} osd.<id>"
  exit
fi

OSD_ID="$1"

printf "Tracking done operations...\n\n"
die() {
  printf "\nExit.\n"
}
trap die EXIT

while :; do
  ceph daemon "$OSD_ID" dump_historic_ops | jq ".ops[] | .description + \" => \" + (.type_data.events[] | select(.event == \"done\") | .time)"
  sleep 0.5
done
