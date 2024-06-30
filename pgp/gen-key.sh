#!/bin/sh

# Run script to generate repository key pair whir will be used for signing files

dir=$(dirname $0)
batch_file=$dir/digie35-pgp-key.batch
name=`grep "Name-Real:" $batch_file | cut -d " " -f 2`

export GNUPGHOME="$(mktemp -d $dir/pgpkeys-XXXXXX)"

echo "Generating key"
gpg --no-tty --batch --gen-key $batch_file

gpg --list-keys

echo "Exporting keys"
gpg --armor --export $name > $dir/pgp-key.public
gpg --armor --export-secret-keys $name > $dir/pgp-key.private

echo "Removing keyring"
rm -rf $GNUPGHOME
