#!/usr/bin/env bash

if [[ -z $VYZZI_SDK_VERSION ]]; then
  >&2 echo "ERROR: This program needs to be run by Vyzzi."
  exit 3
fi

# Read a list of string to match against, one per line.
MATCHERS_PATH="$(mktemp)"
echo "$($VYZZI_SDK_IP_RECEIVE 0 MATCHERS)" | xargs -L1 echo >>$MATCHERS_PATH

# Match to set to which output port to send.
MATCH="$($VYZZI_SDK_IP_RECEIVE 1 MATCH)"
LINE_NO=$(grep -n "$MATCH" "$MATCHERS_PATH" | cut -d: -f1)

# Send all input to the selected sub-port.
$VYZZI_SDK_IP_RECEIVE 0 IN | $VYZZI_SDK_IP_SEND OUT $LINE_NO
