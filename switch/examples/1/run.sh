#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT=$DIR/output
COMPONENT_PATH=$DIR/../../switch.sh

# Resolve IP paths
IP_PATH="$(mktemp)"
cat $DIR/input.txt | awk '{print "'$DIR'/input/" $0}' >$IP_PATH

export PORT_MAP=$DIR/ports.tsv

shell/run.sh $COMPONENT_PATH \
  <$IP_PATH \
  >$OUTPUT/out_1.txt \
  3>$OUTPUT/out_2.txt \
  4>$OUTPUT/out_3.txt \
  5<$DIR/matchers.txt \
  6<<<beta

function print_result {
  NAME=$1
  echo "Result of '$DIR/output/${NAME}':"
  cat $DIR/output/${NAME}
}

print_result out_1.txt
print_result out_2.txt
print_result out_3.txt
