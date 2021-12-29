#!/usr/bin/env bash
find _notes/external/mindoo/ -name "*.md" -exec sed -i "s/$/  /g" {} \;
jekyll build --trace
