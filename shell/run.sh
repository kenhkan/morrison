#!/usr/bin/env bash

WRAPPER=$1

if [[ ! -f "$WRAPPER" ]] || [[ ! -x "$WRAPPER" ]]; then
  >&2 echo "'$WRAPPER' is not executable."
  exit 3
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

>&2 echo "----> Loading Vyzzi shell..."
source $DIR/shell.sh

>&2 echo "----> Vyzzi version: ${VYZZI_SDK_VERSION}."

>&2 echo "----> Starting: '$(realpath $WRAPPER)'"
source $WRAPPER

>&2 echo "----> Exiting Vyzzi shell."
