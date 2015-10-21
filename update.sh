#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

packagesUrl='http://repo.percona.com/apt/dists/jessie/main/binary-amd64/Packages'
packages="$(echo "$packagesUrl" | sed -r 's/[^a-zA-Z.-]+/-/g')"
curl -sSL "${packagesUrl}.gz" | gunzip > "$packages"

for version in "${versions[@]}"; do
	fullVersion="$(grep -m1 -A10 "^Package: percona-server-server-$version\$" "$packages" | grep -m1 '^Version: ' | cut -d' ' -f2)"
	(
		set -x
		cp docker-entrypoint.sh "$version/"
		sed '
			s/%%PERCONA_MAJOR%%/'"$version"'/g;
			s/%%PERCONA_VERSION%%/'"$fullVersion"'/g;
		' Dockerfile.template > "$version/Dockerfile"
	)
done

rm "$packages"
