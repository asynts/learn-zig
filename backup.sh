#!/bin/bash
set -e

~/dev/scripts/backup.rb \
    --name "learn-zig" \
    --url "git@github.com:asynts/learn-zig" \
    --upload "s3://backup.asynts.com/git/learn-zig"
