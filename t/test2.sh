#!/bin/bash

replacement="kkk"

awk -v repl="$replacement" '{gsub(/{MY_KEY}/, repl); print}' yourfile.txt | tee yourfile.txt > /dev/null
