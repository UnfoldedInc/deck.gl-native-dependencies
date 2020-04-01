# deck.gl-native Dependencies

This repository contains prebuilt dependencies for [deck.gl-native](https://github.com/UnfoldedInc/deck.gl-native).

Supported architectures:

| CPU | Operating System
| --- | ----------------
| x64 | Mac OSX
| x64 | Linux (Ubuntu Bionic)

The revision of built libraries can be found in the build script, [./build.sh](./build.sh)

## Build instructions

This repostiroy can be regenerated by `build.sh`. Remember to read the first
lines because they delete your current artifact directories!

`build.sh` uses the following environment variables:

| Variable    | Values
| ----------- | ------
| DEPS_CONFIG | `debug` or `release` - build the given configuration of dependencies. Default `release`
| DEPS_ARCH   | `x64-linux` or `x64-osx` - build to the given output directory. Must match the vcpkg triplet name. Default `x64-linux`
