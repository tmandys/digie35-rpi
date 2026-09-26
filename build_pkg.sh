#!/bin/sh
set -eu

name=rpi-digie35
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir="$dir/apt-repo/pool/main"
version=$(sed -n 's/^Version: //p' "$dir/$name/DEBIAN/control")
[ -n "$version" ] || { echo "Missing package version" >&2; exit 1; }
mkdir -p "$package_dir"
release=-1
for file in "$package_dir/${name}_${version}-"*_all.deb; do
    [ -f "$file" ] || continue
    num=${file##*/}
    num=${num#"${name}_${version}-"}
    num=${num%_all.deb}
    case "$num" in ''|*[!0-9]*) continue ;; esac
    if [ "$num" -gt "$release" ]; then release=$num; fi
done
release=$((release + 1))

# Build a copy: keep the source version unchanged and retain previous releases.
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 1' HUP INT TERM
cp -R "$dir/$name" "$stage/$name"
sed -i "s/^Version: .*/Version: $version-$release/" "$stage/$name/DEBIAN/control"
chmod 755 "$stage/$name/DEBIAN/postinst" "$stage/$name/usr/lib/rpi-digie35/patch-eeprom-config.sh"
dpkg-deb --build "$stage/$name" "$stage/package.deb"
mv "$stage/package.deb" "$package_dir/${name}_${version}-${release}_all.deb"
"$dir/build_repo.sh"
