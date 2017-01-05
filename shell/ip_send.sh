#!/usr/bin/env bash

PORT_NAME=$1
PORT_INDEX=$2

>&2 echo "----> Sending IP..."

# TODO: stub for testing.
PORT_MAP=shell/sample_ports.tsv

if [[ -z $PORT_INDEX ]]; then
  PORT_INDEX=1
fi

PORT_RECORD="$(grep -i "out\t$PORT_NAME\t" $PORT_MAP)"
PORT_STARTING="$(echo "$PORT_RECORD" | cut -f3)"
PORT_LENGTH="$(echo "$PORT_RECORD" | cut -f4)"

if [[ $PORT_INDEX -gt $PORT_LENGTH ]]; then
  >&2 echo "Unaddressible port at $PORT_INDEX given that there are only $PORT_LENGTH ports"
  exit 3
fi

PORT_ADDRESS=$(( $PORT_STARTING + $PORT_INDEX - 1 ))

eval "echo <&$PORT_ADDRESS"
