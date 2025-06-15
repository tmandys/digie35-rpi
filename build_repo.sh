#!/bin/sh

. /etc/os-release

echo "Building APT repository"

dir=$(dirname $0)
repo_dir="$dir/apt-repo"

# generate list of packages in repo
cd $repo_dir
packages_subdir=dists/$VERSION_CODENAME/main/binary-arm64
mkdir -p $packages_subdir

packages=$packages_subdir/Packages
dpkg-scanpackages -m pool/ > $packages
cat $packages | gzip -9 > "$packages.gz"
cd -

cp $dir/pgp/pgp-key.public $repo_dir/repo.gpg.key

# Import key into keyring
private_key=$dir/pgp/pgp-key.private
if [ ! -f $private_key ] ; then
    echo "Private key file does not exist. Generate it first"
    exit 1
fi

name_real=`cat $private_key | gpg --list-packets | grep ":user ID packet:" | sed  -nE 's/.*"([^ ]+).*/\1/p'`

echo "GPG Name: $name_real"
GNUPGHOME="$(mktemp -d pgp/pgpkeys-XXXXXX)"
# get absolute path
export GNUPGHOME=$(cd $GNUPGHOME; pwd)

gpg --import < $private_key

release=Release
# generate releases
do_hash() {
    hash_name=$1
    hash_cmd=$2
    echo "$hash_name:"
    for f in $(find -type f) ; do
        f=$(echo $f | cut -c3- ) # remove ./prefix
        if [ "$f" = "$release" ] ; then
            continue
        fi
        echo " $(${hash_cmd} $f | cut -d " " -f 1) $(wc -c $f)"
    done
}

do_release() {
    suite=$1
    cd $repo_dir/dists/$suite

    cat << EOF > $release
Origin: Digie35 Repository
Label: Digie35
Suite: $suite
Version: 1.0
Architectures: all
Components: main
Description: Digie35 software repository
Date: $(date -Ru)
EOF

    do_hash "MD5Sum" "md5sum" >> $release
    do_hash "SHA1" "sha1sum" >> $release
    do_hash "SHA256" "sha256sum" >> $release

    cat $release | gpg --default-key $name_real -abs > "${release}.gpg"
    cat $release | gpg --default-key $name_real -abs --clearsign > "In${release}"
    cd -
}

do_release "$VERSION_CODENAME"

# Very dangerous when $GNUPGHOME is not set !
# rm -rf $GNUPGHOME
