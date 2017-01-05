#!/usr/bin/env bash

RECEIVE_COUNT=$1
PORT_NAME=$2
PORT_INDEX=$3

if [[ -z $PORT_NAME ]]; then
  >&2 echo "ERROR: No port name is provided."
  exit 5
fi

if [[ "$RECEIVE_COUNT" -ne "$RECEIVE_COUNT" ]]; then
  >&2 echo "ERROR: Receiving count isn't an integer."
  exit 6
fi

>&2 echo "----> Receiving IP..."

RECEIVE_ALL=false
# TODO: stub for testing.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PORT_MAP=$DIR/sample_ports.tsv

if [[ $RECEIVE_COUNT -eq 0 ]]; then
  RECEIVE_ALL=true
fi

if [[ -z $PORT_INDEX ]]; then
  PORT_INDEX=1
fi

PORT_RECORD="$(grep -i "in\t$PORT_NAME\t" $PORT_MAP)"
PORT_STARTING="$(echo "$PORT_RECORD" | cut -f3)"
PORT_LENGTH="$(echo "$PORT_RECORD" | cut -f4)"

if [[ $PORT_INDEX -gt $PORT_LENGTH ]]; then
  >&2 echo "ERROR: Unaddressible port at '$PORT_INDEX' for '$PORT_NAME' given that there are only '$PORT_LENGTH' ports"
  exit 3
fi

PORT_ADDRESS=$(( $PORT_STARTING + $PORT_INDEX - 1 ))

if $RECEIVE_ALL; then
  eval "echo <&$PORT_ADDRESS"
else
  for i in $(seq 1 $RECEIVE_COUNT); do
    read IP
    [[ $? -ne 0 ]] && exit 4
    echo $IP
  done
fi
