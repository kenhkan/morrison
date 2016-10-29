#!/usr/bin/env bash

# This is a sample network, after compilation for *nix.

echo test_data/haiku.txt | ./read_file >/tmp/kktest_03_1

printf "[ PrEfIx { " >/tmp/kktest_03_2
cat /tmp/kktest_03_1 | ./prefix 3</tmp/kktest_03_2 >/tmp/kktest_03_3

echo pond >/tmp/kktest_03_4
cat /tmp/kktest_03_1 | ./grep 3</tmp/kktest_03_4 >/tmp/kktest_03_5

printf " } SuFfIx ]" >/tmp/kktest_03_6
cat /tmp/kktest_03_3 | ./suffix 3</tmp/kktest_03_6 >/tmp/kktest_03_7

# First: prefix and suffix; second: pass-thru; third: filter by "pond".
./print_all 3</tmp/kktest_03_7 4</tmp/kktest_03_1 5</tmp/kktest_03_5
