#!/bin/bash


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
