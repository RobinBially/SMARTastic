#!/bin/bash
set -euo pipefail
: "${1:?Pass the Universal executable path}"
architectures="$(lipo -archs "$1")"
for expected in arm64 x86_64; do
    case " $architectures " in
        *" $expected "*) ;;
        *) echo "Missing $expected in $1 (found: $architectures)" >&2; exit 1 ;;
    esac
done
