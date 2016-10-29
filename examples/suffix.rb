#!/usr/bin/env ruby

# Suffix all lines from fd/0 with the content from fd/3 and print to fd/1.
#
# This is an example of a program inside a wrapper that DOES require remapping
# of I/O to parameters.

require 'open3'

suffix = ARGV[0]

File.open("/dev/fd/1", "w") do |wfd|
  File.open("/dev/fd/0", "r").each_line do |line|
    wfd.write(line.strip + suffix + "\n")
  end
end
