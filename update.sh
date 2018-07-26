#!/bin/bash
set -eo pipefail

defaultSuite='jessie'
declare -A suites=(
#	[5.7]='stretch'
)
declare -A dpkgArchToBashbrew=(
	[amd64]='amd64'
	[armel]='arm32v5'
	[armhf]='arm32v7'
	[arm64]='arm64v8'
	[i386]='i386'
	[ppc64el]='ppc64le'
	[s390x]='s390x'
)

getRemoteVersion() {
	local version="$1"; shift # 10.3
	local suite="$1"; shift # bionic
	local dpkgArch="$1" shift # arm64

	echo "$(
		curl -fsSL "https://repo.percona.com/apt/dists/$suite/main/binary-$dpkgArch/Packages" 2>/dev/null  \
			| tac|tac \
			| awk -v version="$version" -F ': ' '$1 == "Package" { pkg = $2; next } $1 == "Version" && pkg == "percona-server-server-"version { print $2; exit }'
	)"
}

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

#	fullVersion="$(grep -m1 -A10 "^Package: percona-server-server-$version\$" "$packages" | grep -m1 '^Version: ' | cut -d' ' -f2)"
for version in "${versions[@]}"; do
	suite="${suites[$version]:-$defaultSuite}"
	fullVersion="$(getRemoteVersion "$version" "$suite" 'amd64')"
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find $version in $suite"
		continue
	fi

	arches=
	sortedArches="$(echo "${!dpkgArchToBashbrew[@]}" | xargs -n1 | sort | xargs)"
	for arch in $sortedArches; do
		if ver="$(getRemoteVersion "$version" "$suite" "$arch")" && [ -n "$ver" ]; then
			arches="$arches ${dpkgArchToBashbrew[$arch]}"
		fi
	done

	(
		set -x
		sed \
			-e 's/%%PERCONA_MAJOR%%/'"$version"'/g' \
			-e 's/%%PERCONA_VERSION%%/'"$fullVersion"'/g' \
			-e 's!%%SUITE%%!'"$suite"'!g' \
			-e 's!%%ARCHES%%!'"$arches"'!g' \
			Dockerfile.template > "$version/Dockerfile"
	)
done
