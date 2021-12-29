#!/usr/bin/env bash
find _notes/external/mindoo/ -name "*.md" -exec sed -iE "s/$/  /g" {} \;
jekyll build --trace
