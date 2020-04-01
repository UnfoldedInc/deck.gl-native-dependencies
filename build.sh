#!/bin/bash

set -ex

DEPS_CONFIG="linux-x64"
DEPS_ROOT="$(pwd)/$DEPS_CONFIG"
rm -rf "$DEPS_ROOT"

VCPKG_REV=9b44e4768bf25e1ae07e6eaba072c1a1a160f978
DEPOT_TOOLS_REV=a680c23e78599f7f0b761ada3158387a9e9a05b3
DAWN_REV=3da19b843ffd63d884f3a67f2da3eea20818499a

if [ ! -d vcpkg ] ; then git clone https://github.com/Microsoft/vcpkg.git ; fi
pushd vcpkg
git fetch
git checkout "$VCPKG_REV"
./bootstrap-vcpkg.sh -disableMetrics
# vcpkg-root is used to prevent using a user-wide vcpkg
./vcpkg --vcpkg-root "$(pwd)" install jsoncpp gtest range-v3 fmt
./vcpkg --vcpkg-root "$(pwd)" export jsoncpp gtest range-v3 fmt --raw --output="../$DEPS_CONFIG/vcpkg"
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
git checkout "$DAWN_REV"
cp scripts/standalone.gclient .gclient
"$DT_ROOT/gclient" sync

# If the next step opens an editor, close it without changes
EDITOR=true "$DT_ROOT/gn" args out/Release --args="is_debug=false dawn_enable_vulkan=false"
# You may with to specify `-j #` to change the
# number of parallel builds in Ninja.
"$DT_ROOT/ninja" -C out/Release
# TODO Are separate include directories needed for Release/Debug?
mkdir -p "$DEPS_ROOT/dawn/release/include"
cp -R src/include/* "$DEPS_ROOT/dawn/release/include"
cp -R out/Release/gen/src/include/* "$DEPS_ROOT/dawn/release/include"
mkdir -p "$DEPS_ROOT/dawn/release/lib"
cp -R out/Release/*.so "$DEPS_ROOT/dawn/release/lib"

# Repeat same steps for Debug
EDITOR=true "$DT_ROOT/gn" args out/Debug --args="is_debug=true dawn_enable_vulkan=false"
"$DT_ROOT/ninja" -C out/Debug
mkdir -p "$DEPS_ROOT/dawn/debug/include"
cp -R src/include/* "$DEPS_ROOT/dawn/debug/include"
cp -R out/Debug/gen/src/include/* "$DEPS_ROOT/dawn/debug/include"
mkdir -p "$DEPS_ROOT/dawn/debug/lib"
cp -R out/Debug/*.so "$DEPS_ROOT/dawn/debug/lib"

popd
