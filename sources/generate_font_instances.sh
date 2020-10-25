#!/bin/sh

set -euxo pipefail

designspace="$1"
font_format="$2"
output_dir="$3"

## Functions
function die {
  echo "$@" >&2
  exit 1
}

## Argument Validation
if [[ "$#" -ne 3 ]]; then
  die "Received more than three arguments (designspace file, font format, output dir): $@"
fi
if [[ ! -f "$designspace" ]]; then
  die "Designspace file $designspace does not exist!"
fi
case "$font_format" in
  ttf)
  ;;
  otf)
  ;;
  *)
    die "Unrecognized font format $font_format! Should be 'ttf' or 'otf'."
    ;;
esac

## Generating Instances
mkdir -pv "$output_dir"

# We run `ttfautohint` on each output here by adding --autohint.
exec fontmake -m "$designspace" \
     -i \
     -o "$font_format" \
     --output-dir "$output_dir" \
     --autohint '' \
     --timing \
     --verbose=INFO
