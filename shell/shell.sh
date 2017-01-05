#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export VYZZI_SDK_VERSION="$(cat "$DIR/version.txt")"
export VYZZI_SDK_IP_CREATE="$DIR/ip_create.sh"
export VYZZI_SDK_IP_SEND="$DIR/ip_send.sh"
export VYZZI_SDK_IP_RECEIVE="$DIR/ip_receive.sh"
export VYZZI_SDK_IP_OPEN_BRACKET="$DIR/ip_open_bracket.sh"
export VYZZI_SDK_IP_CLOSE_BRACKET="$DIR/ip_close_bracket.sh"
