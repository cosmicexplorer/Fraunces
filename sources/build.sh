#!/bin/sh
set -euxo pipefail

# Ensure this script is executed from within its own directory.
GIT_ROOT="$(git rev-parse --show-toplevel)"
cd "${GIT_ROOT}/sources"


# Only use this when necessary, are currently not all instances are defined in the VF designspace
# files.  generate static designspace referencing csv and variable designspace file later, this
# might not be done dynamically
# python ../mastering/scripts/generate_static_fonts_designspace.py


## Statics
static_fonts=(
  # 3 arguments per line.
  Roman/Fraunces_static.designspace ttf ../fonts/static/ttf
  Roman/Fraunces_static.designspace otf ../fonts/static/otf/
  Italic/FrauncesItalic_static.designspace ttf ../fonts/static/ttf/
  Italic/FrauncesItalic_static.designspace otf ../fonts/static/otf/
)
function get_static_instances_from_designspaces {
  ./extract_instances.sh {Roman,Italic}/*_static.designspace
}


# FIXME: This is a REALLY FANTASTIC CASE where shell scripting is EXCEEDINGLY difficult to work
# with, but JUST AS BAD AS THE PYTHON CODE IN fixNameTable.py and friends!!!! This is a *use case*!!
# NB: Especially take note of:
# (1) The hacky progress bar
# (2) The `stdbuf` unbuffering
# (3) The partial output redirection!
# (4) Being unable to use `xargs` or `parallel` with shell functions means recreating these
#     ".../*_static.designspace" globs in get_static_instances_from_designspaces()!

# NB: Looking to address all of the above with https://github.com/cosmicexplorer/funnel

function generate_static_fonts {
  # This is really quick to calculate, and lets us know how much progress we're making!
  total_num_static_instances="$(get_static_instances_from_designspaces | wc -l)"
  echo "Generating Static fonts ($total_num_static_instances in total)"

  # (1) Process each .designspace XML file and output format in parallel with `xargs`.
  # (2) At this point, we're dealing with a ton of output, so we tee it to stderr so the user can
  #     redirect to /dev/null if they don't need that finer-grained info.
  # (3) However on stdout, we filter for messages that describe successfully writing out a .otf or
  #     .ttf file, and give a quick progress bar with percentage, since we know how *many* instances
  #     we'll eventually need to write, even if we're not checking which exact ones those are.
  instances_processed=0
  printf '%s\n' "${static_fonts[@]}" \
    | 2>&1 stdbuf -i0 -o0 -e0 xargs -t -L 3 --max-procs=0 ./generate_font_instances.sh \
    | stdbuf -i0 -o0 -eL tee /dev/stderr \
    | sed -Ene 's#^INFO:fontmake.font_project:Saving (.*)$#\1#gp' \
    | while read just_saved_font; do
    instances_processed="$(($instances_processed + 1))"
    percent_complete="$((($instances_processed / $total_num_static_instances) / 100.0))"
    echo "${percent_complete}% complete: ${instances_processed}/${total_num_static_instances} (${just_saved_font})"
  done
}

time generate_static_fonts
exit 0

echo "Post processing"

gftools fix-dsig -a ../fonts/static/ttf/*.ttf
gftools fix-hinting ../fonts/static/ttf/*.ttf
# NB: This script appears to be doing something incredibly complex that it absolutely should not be
# attempting to do on its own.
python ../mastering/scripts/fixNameTable.py ../fonts/static/ttf/*.ttf



# ### VF

echo "Generating VFs"
mkdir -p ../fonts
fontmake -m Roman/Fraunces.designspace -o variable --output-path ../fonts/Fraunces[SOFT,WONK,opsz,wght].ttf
fontmake -m Italic/FrauncesItalic.designspace -o variable --output-path ../fonts/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf

vfs=$(printf "%s\n" ../fonts/*.ttf)
echo vfs
echo "Post processing VFs"
for vf in $vfs
do
        gftools fix-dsig -f $vf;
        python ../mastering/scripts/fix_naming.py $vf;
        ttfautohint -v --stem-width-mode=nnn $vf "$vf.fix";
        mv "$vf.fix" $vf;
done

echo "Fixing Hinting"
for vf in $vfs
do
        gftools fix-nonhinting $vf "$vf.fix";
        if [ -f "$vf.fix" ]; then mv "$vf.fix" $vf; fi
done

echo "Fix STAT"
python ../mastering/scripts/add_STAT.py Roman/Fraunces.designspace ../fonts/Fraunces[SOFT,WONK,opsz,wght].ttf
python ../mastering/scripts/add_STAT.py Italic/FrauncesItalic.designspace ../fonts/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf
rm -f Roman/*.stylespace
rm -f Italic/*.stylespace

rm -rf ../fonts/*gasp*

echo "Remove unwanted STAT instances"
for vf in $vfs
do
        # remove unwanted instances
        python ../mastering/scripts/removeUnwantedVFInstances.py $vf
done

echo "Dropping MVAR"
for vf in $vfs
do
        if [ -f "$vf.fix" ]; then mv "$vf.fix" $vf; fi
        ttx -f -x "MVAR" $vf; # Drop MVAR. Table has issue in DW
        rtrip=$(basename -s .ttf $vf)
        new_file=../fonts/$rtrip.ttx;
        rm $vf;
        ttx $new_file
        rm $new_file
done

echo "Fix name table"
for vf in $vfs
do
    python ../mastering/scripts/fixNameTable.py $vf
done


### Cleanup


rm -rf ./*/instances/

rm -f ../fonts/*.ttx
rm -f ../fonts/static/ttf/*.ttx
rm -f ../fonts/*gasp.ttf
rm -f ../fonts/static/ttf/*gasp.ttf

echo "Done Generating"

fontbakery check-googlefonts $vfs  --ghmarkdown checks/fontbakery_var_checks.md
