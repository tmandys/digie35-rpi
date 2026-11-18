#!/bin/sh
# Test the real script with redirected paths and mocked system commands.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/etc" "$fixture/bin"
export fixture
sed -e "s|/etc/|$fixture/etc/|g" \
    -e "s|/sys/firmware/devicetree/base/serial-number|$fixture/serial|g" \
    -e "s|/proc/cpuinfo|$fixture/cpuinfo|g" \
    "$root/rpi-digie35/usr/bin/digie35-set-hostname" > "$fixture/run.sh"
sh -n "$fixture/run.sh"
printf '#!/bin/sh\nprintf "0\\n"\n' > "$fixture/bin/id"
cat > "$fixture/bin/hostnamectl" <<'EOF'
#!/bin/sh
set -eu
[ "${FAIL_HOSTNAMECTL:-0}" = 0 ] || exit 42
[ "$1" = set-hostname ]
printf '%s\n' "$2" > "$fixture/etc/hostname"
EOF
chmod +x "$fixture/bin/id" "$fixture/bin/hostnamectl"
PATH="$fixture/bin:$PATH"
export PATH
printf 'raspberrypi\n' > "$fixture/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 raspberrypi alias # keep\n::1 localhost\n' > "$fixture/etc/hosts"
printf '000000001234ABCD\000' > "$fixture/serial"
sh "$fixture/run.sh"
grep -qx 'digie35-153c2582' "$fixture/etc/hostname"
grep -qx '127.0.1.1[[:space:]]digie35-153c2582 alias # keep' "$fixture/etc/hosts"
cp "$fixture/etc/hosts" "$fixture/first"
sh "$fixture/run.sh"
cmp "$fixture/first" "$fixture/etc/hosts"

# Custom names survive upgrades on this board; --auto resets them.
sh "$fixture/run.sh" --hostname Digie35-2
sh "$fixture/run.sh"
grep -qx 'digie35-2' "$fixture/etc/hostname"
sh "$fixture/run.sh" --auto
grep -qx 'digie35-153c2582' "$fixture/etc/hostname"
sh "$fixture/run.sh" --hostname Digie35-2
# A clone must not retain the original board's custom name.
rm "$fixture/serial"
printf 'Serial\t: 000000001234ffff\n' > "$fixture/cpuinfo"
sh "$fixture/run.sh"
grep -qx 'digie35-f26d1e3a' "$fixture/etc/hostname"
printf '127.0.0.1 localhost\n' > "$fixture/etc/hosts"
sh "$fixture/run.sh"
grep -qx '127.0.1.1[[:space:]]digie35-f26d1e3a' "$fixture/etc/hosts"

cp "$fixture/etc/hosts" "$fixture/first"
cp "$fixture/etc/hostname" "$fixture/old-name"
for serial in '' 0000000000000000 invalid; do
    printf 'Serial : %s\n' "$serial" > "$fixture/cpuinfo"
    if sh "$fixture/run.sh"; then echo 'Invalid serial accepted' >&2; exit 1; fi
done
printf 'Serial : 000000001234aaaa\n' > "$fixture/cpuinfo"
for name in '' '-bad' 'bad-' 'bad/name' 'bad.name' 'bad name' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; do
    if sh "$fixture/run.sh" --hostname "$name"; then echo 'Invalid name accepted' >&2; exit 1; fi
done
if sh "$fixture/run.sh" --hostname; then exit 1; fi
if sh "$fixture/run.sh" --unknown; then exit 1; fi
if FAIL_HOSTNAMECTL=1 sh "$fixture/run.sh"; then exit 1; fi
cmp "$fixture/first" "$fixture/etc/hosts"
cmp "$fixture/old-name" "$fixture/etc/hostname"
echo 'Hostname regression tests passed'
