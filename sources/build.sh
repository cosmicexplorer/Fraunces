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

function generate_static_fonts {
  echo "Generating Static fonts"

  printf '%s\n' "${static_fonts[@]}" \
    | xargs -t -L 3 --max-procs=0 ./generate_font_instances.sh
}

time generate_static_fonts

echo "Post processing"
ttfs=$(printf "%s\n" ../fonts/static/ttf/*.ttf)
for ttf in $ttfs
do
        gftools fix-dsig -f $ttf;
        if [ -f "$ttf.fix" ]; then mv "$ttf.fix" $ttf; fi
        gftools fix-hinting $ttf;
        if [ -f "$ttf.fix" ]; then mv "$ttf.fix" $ttf; fi
    python ../mastering/scripts/fixNameTable.py $ttf
done



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
