#!/usr/bin/env bash

if [ "$VYZZI_SDK_VERSION" -ne "$VYZZI_SDK_VERSION" ]; then
  >&2 echo "ERROR: This program needs to be run by Vyzzi."
  exit 3
fi

# Read a list of string to match against, one per line.
MATCHERS="$(mktemp)"
cat $($VYZZI_SDK_IP_RECEIVE 0 MATCHERS) | xargs -L1 cat >>$MATCHERS

# Match to set to which output port to send.
MATCH="$($VYZZI_SDK_IP_RECEIVE 1 MATCH)"
LINE_NO=$(grep -n "$MATCH" $MATCHERS | cut -d: -f1)

# Send all input to the selected sub-port.
$VYZZI_SDK_IP_RECEIVE 0 IN | $VYZZI_SDK_IP_SEND OUT $LINE_NO
