#!/bin/sh

name=rpi-digie35
dir=$(dirname $0)
repo_dir="$dir/apt-repo"
package_dir="$repo_dir/pool/main"
version=`grep "Version: " "$dir/$name/DEBIAN/control" | cut -d " " -f 2`
# get release number
mkdir -p $package_dir
release=-1
files=`(cd $package_dir && ls ${name}_${version}* 2>/dev/null)`

if [ -n "$files" ] ; then
    for f in $files ; do
        num=`echo $f | cut -d "_" -f 2 | cut -d "-" -f 2`
        if [ $num -gt $release ] ; then
            release=$num
        fi
    done
fi
release=`expr $release + 1`
rm ${package_dir}/${name}_${version}-*_all.deb
dpkg-deb --build "$name" "${package_dir}/${name}_${version}-${release}_all.deb"

${dir}/build_repo.sh
