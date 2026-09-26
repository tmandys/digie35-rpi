#!/bin/sh
set -eu

. /etc/os-release

echo "Building APT repository"
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir="$dir/apt-repo"
private_key="$dir/pgp/pgp-key.private"
[ -f "$private_key" ] || { echo "Private key file does not exist. Generate it first" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 1' HUP INT TERM
GNUPGHOME="$stage/gnupg"
export GNUPGHOME
(umask 077; mkdir "$GNUPGHOME")
gpg --batch --import "$private_key"

# All packages are architecture-independent, published through the ARM64 index.
packages_subdir=main/binary-arm64
mkdir -p "$stage/$packages_subdir"
(cd "$repo_dir" && dpkg-scanpackages -m pool/) > "$stage/$packages_subdir/Packages"
gzip -9 -c "$stage/$packages_subdir/Packages" > "$stage/$packages_subdir/Packages.gz"

cd "$stage"
cat > Release << EOF
Origin: Digie35 Repository
Label: Digie35
Suite: $VERSION_CODENAME
Version: 1.0
Architectures: arm64
Components: main
Description: Digie35 software repository
Date: $(date -Ru)
EOF

do_hash() {
    echo "$1:"
    for file in "$packages_subdir/Packages" "$packages_subdir/Packages.gz"; do
        checksum=$("$2" "$file")
        checksum=${checksum%% *}
        size=$(wc -c < "$file")
        printf ' %s %s %s\n' "$checksum" "$size" "$file"
    done
}
do_hash MD5Sum md5sum >> Release
do_hash SHA1 sha1sum >> Release
do_hash SHA256 sha256sum >> Release
# This isolated keyring contains only the imported repository signing key.
gpg --batch --armor --detach-sign --output Release.gpg Release
gpg --batch --armor --clearsign --output InRelease Release

# Do not publish incomplete indexes when scanning or signing fails.
destination="$repo_dir/dists/$VERSION_CODENAME"
mkdir -p "$destination/$packages_subdir"
cp "$packages_subdir/Packages" "$packages_subdir/Packages.gz" "$destination/$packages_subdir/"
cp Release Release.gpg InRelease "$destination/"
cp "$dir/pgp/pgp-key.public" "$repo_dir/repo.gpg.key"
