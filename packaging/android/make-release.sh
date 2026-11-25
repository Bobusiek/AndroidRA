#!/bin/bash
# Builds a signed release APK for GitHub Releases.
#
# Usage:
#   ./packaging/android/make-release.sh
#
# Creates the release signing key on first use (default ~/androidra-release.jks, alias "androidra"),
# asks for its password without echoing it, and runs build-apk.sh. The APK and its SHA-256 checksum
# end up in release/. Keep the keystore and its password safe: every future update must be signed
# with the same key, and neither may ever be committed.
set -o errexit -o pipefail -o nounset

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export OPENRA_KEYSTORE="${OPENRA_KEYSTORE:-${HOME}/androidra-release.jks}"
export OPENRA_KEY_ALIAS="${OPENRA_KEY_ALIAS:-androidra}"

if [ ! -f "${OPENRA_KEYSTORE}" ]; then
	echo "No release key found at ${OPENRA_KEYSTORE}; creating one now."
	echo "Choose a strong password and remember it. Back up the key file afterwards."
	echo
	keytool -genkeypair -v -keystore "${OPENRA_KEYSTORE}" -alias "${OPENRA_KEY_ALIAS}" \
		-keyalg RSA -keysize 4096 -validity 10000
	chmod 600 "${OPENRA_KEYSTORE}"
	echo
fi

read -r -s -p "Password for ${OPENRA_KEYSTORE}: " OPENRA_KEYSTORE_PASS
echo
export OPENRA_KEYSTORE_PASS

exec "${ROOT_DIR}/packaging/android/build-apk.sh" "$@"
