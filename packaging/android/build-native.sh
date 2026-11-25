#!/bin/bash
# Builds the native libraries required by OpenRA.Android with the Android NDK:
#   libSDL2.so, libsoft_oal.so (OpenAL Soft), libfreetype6.so, liblua51.so and libmain.so
# and copies SDL's Java glue sources that must match the libSDL2.so version.
#
# Usage:
#   ./packaging/android/build-native.sh
#
# Environment:
#   ANDROID_HOME       Android SDK root (default: ~/Android/Sdk)
#   ANDROID_NDK_HOME   NDK root (default: newest $ANDROID_HOME/ndk/*)
#   ABIS               Space separated ABIs (default: "arm64-v8a"; add "x86_64" for the emulator)
#   ANDROID_API        Minimum API level (default: 24, must match SupportedOSPlatformVersion)
set -o errexit -o pipefail -o nounset

SDL_VERSION="2.32.10"
OPENAL_VERSION="1.24.3"
FREETYPE_VERSION="2.13.3"
LUA_VERSION="5.1.5"

# SHA-256 of the source archives above; update together with the versions
SDL_SHA256="5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165"
OPENAL_SHA256="7e1fecdeb45e7f78722b776c5cf30bd33934b961d7fd2a11e0494e064cc631ce"
FREETYPE_SHA256="0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289"
LUA_SHA256="2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/OpenRA.Android"
WORK_DIR="${PROJECT_DIR}/obj/native"
SRC_DIR="${WORK_DIR}/src"
DL_DIR="${WORK_DIR}/downloads"

ANDROID_HOME="${ANDROID_HOME:-${HOME}/Android/Sdk}"
ABIS="${ABIS:-arm64-v8a}"
ANDROID_API="${ANDROID_API:-24}"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
	ANDROID_NDK_HOME="$(find "${ANDROID_HOME}/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
fi

if [ -z "${ANDROID_NDK_HOME}" ] || [ ! -f "${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" ]; then
	echo "Android NDK not found. Install it with:" >&2
	echo "  \"${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager\" \"ndk;29.0.14206865\"" >&2
	exit 1
fi

# Prefer a system cmake/ninja, otherwise fall back to the SDK's cmake package (which bundles ninja).
CMAKE="$(command -v cmake || true)"
if [ -z "${CMAKE}" ]; then
	SDK_CMAKE_DIR="$(find "${ANDROID_HOME}/cmake" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
	if [ -n "${SDK_CMAKE_DIR}" ]; then
		CMAKE="${SDK_CMAKE_DIR}/bin/cmake"
		export PATH="${SDK_CMAKE_DIR}/bin:${PATH}"
	fi
fi

if [ -z "${CMAKE}" ] || ! command -v ninja >/dev/null; then
	echo "cmake and ninja are required. Install them with 'sudo pacman -S cmake ninja' or:" >&2
	echo "  \"${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager\" \"cmake;3.31.6\"" >&2
	exit 1
fi

TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake"
LLVM_BIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"

# Android 15+ devices may use 16 KB memory pages
PAGE_SIZE_LDFLAGS="-Wl,-z,max-page-size=16384"

# Keep the builder's absolute paths (e.g. their home directory) out of __FILE__ strings in the binaries
PATH_MAP_CFLAGS="-ffile-prefix-map=${ROOT_DIR}=."

echo "Using NDK: ${ANDROID_NDK_HOME}"
echo "Using cmake: ${CMAKE}"
echo "ABIs: ${ABIS} (API ${ANDROID_API})"

mkdir -p "${SRC_DIR}" "${DL_DIR}"

# verify FILE SHA256: succeeds only if the file matches the pinned checksum
verify() {
	echo "${2}  ${1}" | sha256sum --check --status
}

# download FILENAME SHA256 URL [MIRROR_URL...]
# Sources are pinned by checksum so a compromised server or mirror cannot inject code into the APK.
download() {
	local file="${1}" sha256="${2}"
	shift 2

	if [ -f "${DL_DIR}/${file}" ] && ! verify "${DL_DIR}/${file}" "${sha256}"; then
		echo "Cached ${file} does not match its checksum, downloading it again" >&2
		rm -f "${DL_DIR}/${file}"
	fi

	if [ ! -f "${DL_DIR}/${file}" ]; then
		for url in "$@"; do
			echo "Downloading ${url}"
			if curl -fsSL --proto '=https' --retry 3 --retry-all-errors -o "${DL_DIR}/${file}.part" "${url}"; then
				if verify "${DL_DIR}/${file}.part" "${sha256}"; then
					mv "${DL_DIR}/${file}.part" "${DL_DIR}/${file}"
					break
				fi

				echo "Checksum mismatch for ${url}, trying the next mirror" >&2
				rm -f "${DL_DIR}/${file}.part"
			fi
		done

		if [ ! -f "${DL_DIR}/${file}" ]; then
			echo "Failed to download a verified copy of ${file}" >&2
			exit 1
		fi
	fi
}

# extract FILENAME DIRNAME
extract() {
	if [ ! -d "${SRC_DIR}/${2}" ]; then
		tar -xf "${DL_DIR}/${1}" -C "${SRC_DIR}"
	fi
}

download "SDL2-${SDL_VERSION}.tar.gz" "${SDL_SHA256}" \
	"https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL2-${SDL_VERSION}.tar.gz"
download "openal-soft-${OPENAL_VERSION}.tar.gz" "${OPENAL_SHA256}" \
	"https://github.com/kcat/openal-soft/archive/refs/tags/${OPENAL_VERSION}.tar.gz"
download "freetype-${FREETYPE_VERSION}.tar.xz" "${FREETYPE_SHA256}" \
	"https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz" \
	"https://sourceforge.net/projects/freetype/files/freetype2/${FREETYPE_VERSION}/freetype-${FREETYPE_VERSION}.tar.xz/download"
download "lua-${LUA_VERSION}.tar.gz" "${LUA_SHA256}" \
	"https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" \
	"https://www.tecgraf.puc-rio.br/lua/mirror/ftp/lua-${LUA_VERSION}.tar.gz"

extract "SDL2-${SDL_VERSION}.tar.gz" "SDL2-${SDL_VERSION}"
extract "openal-soft-${OPENAL_VERSION}.tar.gz" "openal-soft-${OPENAL_VERSION}"
extract "freetype-${FREETYPE_VERSION}.tar.xz" "freetype-${FREETYPE_VERSION}"
extract "lua-${LUA_VERSION}.tar.gz" "lua-${LUA_VERSION}"

# SDL's Java classes must match the native library exactly
echo "Copying SDL Java sources"
rm -rf "${PROJECT_DIR}/java/org/libsdl"
mkdir -p "${PROJECT_DIR}/java/org/libsdl/app"
cp "${SRC_DIR}/SDL2-${SDL_VERSION}/android-project/app/src/main/java/org/libsdl/app/"*.java "${PROJECT_DIR}/java/org/libsdl/app/"

# cmake_build NAME SOURCE_DIR ABI [EXTRA_ARGS...]
cmake_build() {
	local name="${1}" source="${2}" abi="${3}"
	shift 3
	local build="${WORK_DIR}/build/${abi}/${name}"

	# The NDK toolchain adds its hardening flags separately, so CMAKE_C_FLAGS can safely carry the path map
	"${CMAKE}" -S "${source}" -B "${build}" -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
		-DANDROID_ABI="${abi}" \
		-DANDROID_PLATFORM="android-${ANDROID_API}" \
		-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_FLAGS="${PATH_MAP_CFLAGS}" \
		-DCMAKE_CXX_FLAGS="${PATH_MAP_CFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${PAGE_SIZE_LDFLAGS}" \
		"$@"
	"${CMAKE}" --build "${build}"
}

# find_lib BUILD_DIR NAME -> path of the built shared library
find_lib() {
	find "${1}" -name "${2}" -type f | head -n 1
}

for ABI in ${ABIS}; do
	case "${ABI}" in
		arm64-v8a) TRIPLE="aarch64-linux-android" ;;
		armeabi-v7a) TRIPLE="armv7a-linux-androideabi" ;;
		x86_64) TRIPLE="x86_64-linux-android" ;;
		x86) TRIPLE="i686-linux-android" ;;
		*) echo "Unsupported ABI ${ABI}" >&2; exit 1 ;;
	esac

	CC="${LLVM_BIN}/${TRIPLE}${ANDROID_API}-clang"
	OUT_DIR="${PROJECT_DIR}/libs/${ABI}"
	BUILD_DIR="${WORK_DIR}/build/${ABI}"
	mkdir -p "${OUT_DIR}" "${BUILD_DIR}"

	echo "=== ${ABI}: SDL2 ${SDL_VERSION}"
	cmake_build sdl2 "${SRC_DIR}/SDL2-${SDL_VERSION}" "${ABI}" \
		-DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF
	cp "$(find_lib "${BUILD_DIR}/sdl2" libSDL2.so)" "${OUT_DIR}/libSDL2.so"

	echo "=== ${ABI}: OpenAL Soft ${OPENAL_VERSION}"
	cmake_build openal "${SRC_DIR}/openal-soft-${OPENAL_VERSION}" "${ABI}" \
		-DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_INSTALL=OFF \
		-DALSOFT_BACKEND_OPENSL=ON -DALSOFT_REQUIRE_OPENSL=ON
	cp "$(find_lib "${BUILD_DIR}/openal" libopenal.so)" "${OUT_DIR}/libsoft_oal.so"

	echo "=== ${ABI}: FreeType ${FREETYPE_VERSION}"
	cmake_build freetype "${SRC_DIR}/freetype-${FREETYPE_VERSION}" "${ABI}" \
		-DBUILD_SHARED_LIBS=ON \
		-DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON \
		-DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON
	cp "$(find_lib "${BUILD_DIR}/freetype" 'libfreetype*.so')" "${OUT_DIR}/libfreetype6.so"

	echo "=== ${ABI}: Lua ${LUA_VERSION}"
	LUA_SRC="${SRC_DIR}/lua-${LUA_VERSION}/src"
	LUA_FILES=()
	for f in "${LUA_SRC}"/*.c; do
		case "$(basename "${f}")" in
			lua.c|luac.c|print.c) ;;
			*) LUA_FILES+=("${f}") ;;
		esac
	done
	"${CC}" -shared -fPIC -O2 ${PATH_MAP_CFLAGS} -DLUA_USE_POSIX -DLUA_USE_DLOPEN \
		-Wl,-soname,liblua51.so ${PAGE_SIZE_LDFLAGS} \
		-o "${OUT_DIR}/liblua51.so" "${LUA_FILES[@]}" -lm -ldl

	echo "=== ${ABI}: libmain"
	"${CC}" -shared -fPIC -O2 ${PATH_MAP_CFLAGS} -Wall \
		-Wl,-soname,libmain.so ${PAGE_SIZE_LDFLAGS} \
		-o "${OUT_DIR}/libmain.so" "${PROJECT_DIR}/native/main.c" -llog

	"${LLVM_BIN}/llvm-strip" --strip-unneeded "${OUT_DIR}"/*.so
	ls -la "${OUT_DIR}"
done

echo "Native libraries are ready in ${PROJECT_DIR}/libs"
