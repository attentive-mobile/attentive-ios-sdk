#!/bin/bash

if ! command -v clang-format-11 &> /dev/null
then
    echo "clang-format-11 could not be found. Install using: brew install clang-format@11"
    exit
fi

FILES_TO_LINT=$(find . \( \
  -path "./Vendor/*" -prune -o \
  -path "./*/Pods/*" -prune -o \
  -path "./DerivedData/*" -prune -o \
  -path "./build/*" -prune -o \
  -path "./*/DerivedData/*" -prune -o \
  -path "./*/build/*" -prune -o \
  -path "./attentive-ios-sdk.xc*" -prune \
  \) \
  -o -name "*.h" -o -name "*.m" -print)


clang-format-11 -i --assume-filename=Objective-C $FILES_TO_LINT
