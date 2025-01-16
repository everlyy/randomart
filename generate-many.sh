#! /usr/bin/env sh

set -xe

WIDTH=4096
HEIGHT=4096

EXECUTABLE=build/bin/randomart
DIR=many

make $EXECUTABLE

mkdir -p $DIR

while :
do
    seed=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
    ppm_file="$DIR/$seed.ppm"
    png_file="$DIR/$seed.png"

    $EXECUTABLE $ppm_file -s "$seed" -l $(shuf -i 8-15 -n 1) -w $WIDTH -h $HEIGHT -j
    convert "$ppm_file" "$png_file"
    rm "$ppm_file"
done
