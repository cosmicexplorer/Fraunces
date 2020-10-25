#!/bin/sh

# Extract the font variant names from the .ufo names of <instance> elements in .designspace files.
printf '%s\n' "$@" \
  | xargs -L 1 --max-procs=0 \
          ./extract_instances.py \
  | grep -ve '^$' \
  | sed -Ee 's#\.ufo$##g'
