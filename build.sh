#!/bin/bash

set -ex

# Should be release or debug (case sensitive)
DEPS_CONFIG="release"
# Note this should match the vcpkg triplet name,
# such as x64-linux or x64-osx
DEPS_ARCH="${DEPS_ARCH:-x64-linux}"
DEPS_ROOT="$(pwd)/$DEPS_ARCH"
rm -rf "$DEPS_ROOT"

VCPKG_REV=9b44e4768bf25e1ae07e6eaba072c1a1a160f978
DEPOT_TOOLS_REV=a680c23e78599f7f0b761ada3158387a9e9a05b3
DAWN_REV=3da19b843ffd63d884f3a67f2da3eea20818499a

if [ ! -d vcpkg ] ; then git clone https://github.com/Microsoft/vcpkg.git ; fi
pushd vcpkg
git fetch
# git reset is being done to wipe out the triplet change below.
git reset --hard HEAD
git checkout "$VCPKG_REV"
# TODO: May repeatedly add this to the triplet file, so using git reset above
echo "set(VCPKG_BUILD_TYPE $DEPS_CONFIG)" >> "triplets/$DEPS_ARCH.cmake"
./bootstrap-vcpkg.sh -disableMetrics
# vcpkg-root is used to prevent using a user-wide vcpkg
./vcpkg --vcpkg-root "$(pwd)" install jsoncpp gtest range-v3 fmt
./vcpkg --vcpkg-root "$(pwd)" export jsoncpp gtest range-v3 fmt --raw --output="../$DEPS_ARCH/vcpkg"
popd

# For dawn, follow the standard build instructions:
if [ ! -d depot_tools ] ; then git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ; fi
pushd depot_tools
# You may add depot_tools to your path rather than using
# absolute or relative paths.
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
EDITOR=true "$DT_ROOT/gn" args "out/$DEPS_CONFIG" --args="is_debug=$DAWN_IS_DEBUG dawn_enable_vulkan=false"
# You may with to specify `-j #` to change the
# number of parallel builds in Ninja.
"$DT_ROOT/ninja" -C "out/$DEPS_CONFIG"
mkdir -p "$DEPS_ROOT/dawn/$DEPS_CONFIG/include"
cp -R src/include/* "$DEPS_ROOT/dawn/$DEPS_CONFIG/include"
cp -R out/$DEPS_CONFIG/gen/src/include/* "$DEPS_ROOT/dawn/$DEPS_CONFIG/include"
mkdir -p "$DEPS_ROOT/dawn/$DEPS_CONFIG/lib"
cp -R out/$DEPS_CONFIG/*.so "$DEPS_ROOT/dawn/$DEPS_CONFIG/lib"

popd
