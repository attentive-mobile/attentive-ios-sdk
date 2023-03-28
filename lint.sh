#!/bin/bash

set -x

HOST=${1:-local}


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


case "$HOST" in
  local)
    clang-format-11 -i --assume-filename=Objective-C $FILES_TO_LINT
    ;;

  ci)
    clang-format --dry-run --Werror --assume-filename=Objective-C
    ;;
  *)
    echo "invalid host name"
    exit 1
    ;;
esac
