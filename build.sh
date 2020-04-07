#!/bin/bash

set -ex

# Should be release or debug (case sensitive)
DEPS_CONFIG="release"
# Note this should match the vcpkg triplet name,
# such as x64-linux or x64-osx
DEPS_ARCH="${DEPS_ARCH:-x64-linux}"
DEPS_ROOT="$(pwd)/$DEPS_ARCH"
DEPS_INCLUDE_FOLDER="$DEPS_ROOT/include"
DEPS_LIB_FOLDER="$DEPS_ROOT/lib"

if [ "$DEPS_ARCH" = "x64-osx" ] ; then
  IS_MAC=true
else
  IS_MAC=false
fi

# Dependency revisions to use
VCPKG_REV=9b44e4768bf25e1ae07e6eaba072c1a1a160f978
DEPOT_TOOLS_REV=a680c23e78599f7f0b761ada3158387a9e9a05b3
DAWN_REV=3da19b843ffd63d884f3a67f2da3eea20818499a

# Wipe out existing artifacts and replace with the ones that are now being built
rm -rf "$DEPS_ROOT"

mkdir -p "$DEPS_INCLUDE_FOLDER"
mkdir -p "$DEPS_LIB_FOLDER"

# vcpkg
if [ ! -d vcpkg ] ; then git clone https://github.com/Microsoft/vcpkg.git ; fi
pushd vcpkg
git fetch
# git reset is being done to wipe out the triplet change below, if this is a rerun
git reset --hard HEAD
git checkout "$VCPKG_REV"
# TODO: May repeatedly add this to the triplet file, so using git reset above
# TODO: can't because arrow has dependencies that need the debug build
#echo "set(VCPKG_BUILD_TYPE $DEPS_CONFIG)" >> "triplets/$DEPS_ARCH.cmake"
./bootstrap-vcpkg.sh -disableMetrics
# vcpkg-root is used to prevent using a user-wide vcpkg
VCPKG_DEPENDENCIES="jsoncpp gtest range-v3 fmt shaderc"
# Installing arrow through vcpkg fails using this revision of vcpkg. We handle this in a special way
if ! $IS_MAC ; then VCPKG_DEPENDENCIES="$VCPKG_DEPENDENCIES arrow" ; fi
# Ignore the expansion here because we are intentionally splitting on spaces to get vcpkg to install a list of packages.
# shellcheck disable=SC2086
./vcpkg --vcpkg-root "$(pwd)" install $VCPKG_DEPENDENCIES
# Copy over headers and libs. Not using vcpkg export as it creates a lot of intermediate folders
cp -R "installed/$DEPS_ARCH/include/"* "$DEPS_INCLUDE_FOLDER"
cp -R "installed/$DEPS_ARCH/lib/"*.a "$DEPS_LIB_FOLDER"
popd

# For dawn, follow the standard build instructions: https://dawn.googlesource.com/dawn/+/HEAD/docs/buiding.md
if [ ! -d depot_tools ] ; then git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ; fi
pushd depot_tools
# You may add depot_tools to your path rather than using absolute or relative paths
DT_ROOT="$(pwd)"
git fetch
git checkout "$DEPOT_TOOLS_REV"
popd
if [ ! -d dawn ] ; then git clone https://dawn.googlesource.com/dawn ; fi
pushd dawn
git fetch
git checkout "$DAWN_REV"
cp scripts/standalone.gclient .gclient
"$DT_ROOT/gclient" sync

if [ "$DEPS_CONFIG" = "release" ] ; then
    DAWN_IS_DEBUG="false"
else
    DAWN_IS_DEBUG="true"
fi

# Override EDITOR to prevent bringing up the editor during the build.
# TODO: disable building tests
EDITOR=true "$DT_ROOT/gn" args "out/$DEPS_CONFIG" --args="is_debug=$DAWN_IS_DEBUG"
# You may with to specify `-j #` to change the number of parallel builds in Ninja.
"$DT_ROOT/ninja" -C "out/$DEPS_CONFIG"
cp -R "src/include/"* "$DEPS_INCLUDE_FOLDER"
cp -R "out/$DEPS_CONFIG/gen/src/include/"* "$DEPS_INCLUDE_FOLDER"
cp -R third_party/glfw/include/* "$DEPS_INCLUDE_FOLDER"

# These are .so on Linux, and .dylib on Mac
if [ -f "out/$DEPS_CONFIG/libdawn_native.dylib" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_native.dylib" "$DEPS_LIB_FOLDER"
fi
if [ -f "out/$DEPS_CONFIG/libdawn_native.so" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_native.so" "$DEPS_LIB_FOLDER"
fi

if [ -f "out/$DEPS_CONFIG/libdawn_proc.dylib" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_proc.dylib" "$DEPS_LIB_FOLDER"
fi
if [ -f "out/$DEPS_CONFIG/libdawn_proc.so" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_proc.so" "$DEPS_LIB_FOLDER"
fi

if [ -f "out/$DEPS_CONFIG/libdawn_wire.dylib" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_wire.dylib" "$DEPS_LIB_FOLDER"
fi
if [ -f "out/$DEPS_CONFIG/libdawn_wire.so" ] ; then
    cp "out/$DEPS_CONFIG/libdawn_wire.so" "$DEPS_LIB_FOLDER"
fi

cp "out/$DEPS_CONFIG/obj/libdawn_bindings.a" "$DEPS_LIB_FOLDER"
cp "out/$DEPS_CONFIG/obj/third_party/libglfw.a" "$DEPS_LIB_FOLDER"
cp "out/$DEPS_CONFIG/obj/src/dawn/dawncpp/webgpu_cpp.o" "$DEPS_LIB_FOLDER"

popd

# macOS specific setup
if $IS_MAC ; then
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi

    # Lookup version 0.16.0 and install it
    # We could create our own cask and maintain it, but as noted above this is (hopefully) a temporary solution
    ARROW_VERSION=0.16.0
    brew extract --force apache-arrow homebrew/cask "--version=$ARROW_VERSION"
    brew install "homebrew/cask/apache-arrow@$ARROW_VERSION"

    # TODO: Can this path be detected at runtime?
    cp -R "/usr/local/Cellar/apache-arrow/$ARROW_VERSION/include/" "$DEPS_INCLUDE_FOLDER"
    cp -R "/usr/local/Cellar/apache-arrow/$ARROW_VERSION/lib/libarrow.a" "$DEPS_LIB_FOLDER"
fi
