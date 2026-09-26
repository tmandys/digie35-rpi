#!/bin/sh
# All writes go to temporary fixtures. No system installation or signing keys.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d)

for file in "$root/build_pkg.sh" "$root/build_repo.sh" "$root/rpi-digie35/DEBIAN/postinst" "$root/rpi-digie35/usr/lib/rpi-digie35/patch-eeprom-config.sh"; do
    sh -n "$file"
done
printf 'BOOT_ORDER=0xf41\n# PSU_MAX_CURRENT=2000\n' > "$fixture/eeprom"
sh "$root/rpi-digie35/usr/lib/rpi-digie35/patch-eeprom-config.sh" "$fixture/eeprom"
grep -qx 'PSU_MAX_CURRENT=4000' "$fixture/eeprom"
cp "$fixture/eeprom" "$fixture/first"
sh "$root/rpi-digie35/usr/lib/rpi-digie35/patch-eeprom-config.sh" "$fixture/eeprom"
cmp "$fixture/eeprom" "$fixture/first"

# Invoke build_pkg from a different working directory, with spaces in its path.
project="$fixture/test project"
mkdir -p "$project" "$fixture/bin"
cp "$root/build_pkg.sh" "$project/"
cp -R "$root/rpi-digie35" "$project/"
printf '#!/bin/sh\nexit 0\n' > "$project/build_repo.sh"
chmod +x "$project/build_repo.sh"
cat > "$fixture/bin/dpkg-deb" <<'EOF'
#!/bin/sh
set -eu
[ "${FAIL_BUILD:-0}" = 0 ] || exit 42
sed -n 's/^Version: //p' "$2/DEBIAN/control" > "$3"
[ -x "$2/usr/lib/rpi-digie35/patch-eeprom-config.sh" ]
[ ! -f "$2/DEBIAN/patch-eeprom-config.sh" ]
EOF
chmod +x "$fixture/bin/dpkg-deb"
PATH="$fixture/bin:$PATH"
export PATH
cd "$fixture"
sh "$project/build_pkg.sh"
sh "$project/build_pkg.sh"
grep -qx '0.5-0' "$project/apt-repo/pool/main/rpi-digie35_0.5-0_all.deb"
grep -qx '0.5-1' "$project/apt-repo/pool/main/rpi-digie35_0.5-1_all.deb"
grep -qx 'Version: 0.5' "$project/rpi-digie35/DEBIAN/control"
if FAIL_BUILD=1 sh "$project/build_pkg.sh"; then
    echo 'Build failure was ignored' >&2
    exit 1
fi
[ ! -f "$project/apt-repo/pool/main/rpi-digie35_0.5-2_all.deb" ]

# Exercise repository metadata generation without real signing or dpkg tools.
printf 'VERSION_CODENAME=test\n' > "$fixture/os-release"
sed "s|/etc/os-release|\"$fixture/os-release\"|" "$root/build_repo.sh" > "$project/build_repo.sh"
mkdir -p "$project/pgp"
printf 'test key\n' > "$project/pgp/pgp-key.private"
printf 'test public key\n' > "$project/pgp/pgp-key.public"
cat > "$fixture/bin/gpg" <<'EOF'
#!/bin/sh
set -eu
[ "${FAIL_SIGN:-0}" = 0 ] || exit 43
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then cp Release "$2"; exit 0; fi
    shift
done
EOF
cat > "$fixture/bin/dpkg-scanpackages" <<'EOF'
#!/bin/sh
printf 'Package: rpi-digie35\nVersion: 0.5-1\nArchitecture: all\n'
EOF
chmod +x "$fixture/bin/gpg" "$fixture/bin/dpkg-scanpackages"
sh "$project/build_repo.sh"
sh "$project/build_repo.sh"
release="$project/apt-repo/dists/test/Release"
grep -qx 'Architectures: arm64' "$release"
[ "$(grep -c 'main/binary-arm64/Packages' "$release")" -eq 6 ]
if grep -q 'Release.gpg\|InRelease' "$release"; then exit 1; fi
cp "$release" "$fixture/previous-release"
if FAIL_SIGN=1 sh "$project/build_repo.sh"; then exit 1; fi
cmp "$release" "$fixture/previous-release"
echo 'Shell regression tests passed'
