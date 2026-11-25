#!/bin/bash
# Builds the OpenRA Android APK (Release).
#
# Usage:
#   ./packaging/android/build-apk.sh [extra dotnet publish arguments]
#
# Run ./packaging/android/build-native.sh first to build the native libraries.
#
# Signing: without the variables below the APK is signed with the local .NET Android debug key,
# which is fine for installing on your own devices. To sign a build for distribution, create your own
# keystore (keep it and its passwords private, never commit them) and set:
#   OPENRA_KEYSTORE        Path to the keystore file
#   OPENRA_KEY_ALIAS       Key alias inside the keystore
#   OPENRA_KEYSTORE_PASS   Keystore password (read from the environment, not stored anywhere)
#   OPENRA_KEY_PASS        Key password (defaults to OPENRA_KEYSTORE_PASS)
set -o errexit -o pipefail -o nounset

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="${ROOT_DIR}/OpenRA.Android/OpenRA.Android.csproj"

if [ ! -f "${ROOT_DIR}/OpenRA.Android/libs/arm64-v8a/libSDL2.so" ]; then
	echo "Native libraries are missing. Run ./packaging/android/build-native.sh first." >&2
	exit 1
fi

ARGS=(
	-c Release
	-f net10.0-android
	# Replace the absolute source path (which contains the builder's user name) in the compiled assemblies
	"-p:PathMap=${ROOT_DIR}=/_"
)

if [ -n "${OPENRA_KEYSTORE:-}" ]; then
	: "${OPENRA_KEY_ALIAS:?OPENRA_KEY_ALIAS must be set when OPENRA_KEYSTORE is used}"
	: "${OPENRA_KEYSTORE_PASS:?OPENRA_KEYSTORE_PASS must be set when OPENRA_KEYSTORE is used}"
	export OPENRA_KEY_PASS="${OPENRA_KEY_PASS:-${OPENRA_KEYSTORE_PASS}}"

	# The env: prefix makes the build read the passwords from the environment instead of the command line
	ARGS+=(
		-p:AndroidKeyStore=true
		"-p:AndroidSigningKeyStore=${OPENRA_KEYSTORE}"
		"-p:AndroidSigningKeyAlias=${OPENRA_KEY_ALIAS}"
		-p:AndroidSigningStorePass=env:OPENRA_KEYSTORE_PASS
		-p:AndroidSigningKeyPass=env:OPENRA_KEY_PASS
	)
fi

dotnet publish "${PROJECT}" "${ARGS[@]}" "$@"

APK="${ROOT_DIR}/OpenRA.Android/bin/Release/publish/pl.androidra-Signed.apk"

# Copy a versioned APK and its checksum to release/ (ignored by git) for uploading to GitHub Releases
VERSION="$(sed -n 's|.*<ApplicationDisplayVersion>\(.*\)</ApplicationDisplayVersion>.*|\1|p' "${PROJECT}")"
RELEASE_DIR="${ROOT_DIR}/release"
RELEASE_APK="AndroidRA-${VERSION}-arm64.apk"
mkdir -p "${RELEASE_DIR}"
cp "${APK}" "${RELEASE_DIR}/${RELEASE_APK}"
(cd "${RELEASE_DIR}" && sha256sum "${RELEASE_APK}" > "${RELEASE_APK}.sha256")

echo
echo "APK: ${APK}"
echo "Release files: ${RELEASE_DIR}/${RELEASE_APK} (+ .sha256)"
if [ -z "${OPENRA_KEYSTORE:-}" ]; then
	echo "Note: signed with the local debug key. Set OPENRA_KEYSTORE etc. to sign a public release."
fi
