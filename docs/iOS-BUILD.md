# Library Build Details

As noted in [README](https://github.com/UnfoldedInc/deck.gl-native-dependencies/blob/master/README.md), some of the iOS dependencies are built manually due to lack of first-class support by package managers and libraries themselves. This document describes steps taken to build each of those dependencies. Note that building some of the dependencies required workarounds that patch up issues with current versions of build tools, which may not necessarily be applicable in the future.

## Dawn (3da19b843ffd63d884f3a67f2da3eea20818499a)

### Resources

- http://webrtc.github.io/webrtc-org/native-code/ios/
- https://gn.googlesource.com/gn/+/master/docs/reference.md
- https://chromium.googlesource.com/chromium/src/tools/gn/+/48062805e19b4697c5fbd926dc649c78b6aaa138/docs/quick_start.md
- https://v8.dev/docs/cross-compile-ios

### Issues and solutions/workarounds

iOS was not part of the build system setup, so a few tweaks had to be made in order to enable it. These additions are available as a git patch that can be found [here](/patches/dawn/dawn-iOS-build.patch).

#### Modifying the install path
Resulting .dylib files use relative install paths such as `./libdawn_native.dylib`. This can likely be specified as part of build settings, but it's not clear how to do that with Ninja. The libraries that are checked in have these install paths modified as such: `install_name_tool -id @rpath/libdawn_native.dylib libdawn_native.dylib`. Using `@rpath` makes it so that runtime lookup path can be specified when building the product instead of having them be tied to the executable

### Building

After applying solutions and workarounds mentioned above, following commands were used to configure and build `dawn`:

```
gn gen out/ios --args='
  target_os="ios"                # Target iOS - https://gn.googlesource.com/gn/+/master/docs/reference.md#var_target_os
  target_cpu="arm64"             # Target CPU architecture - https://gn.googlesource.com/gn/+/master/docs/reference.md#var_target_cpu
                                 # This should be either arm64 (device) or x64 (simulator)
  ios_enable_code_signing=false  # Disable code signing as it is not necessary
  is_debug=false                 # Release build
  enable_ios_bitcode=true        # Enable bitcode explicitly
  ios_deployment_target="12.0"   # iOS deployment target, minimum is 12.0 (device) or 13.0 (simulator)
  is_component_build=false       
  use_custom_libcxx=false
  '
```

```
ninja -C out/ios
```

### Additional Notes

- `Dawn` makes use of some Metal API that is available on iOS12+, so `ios_deployment_target` has to be set to `12.0` or higher when building for a device
- `Metal` became available on simulators with iOS13, so when building for simulator (`x64`), `ios_deployment_target` has to be `13.0` or higher
- `Dawn` cannot be built for 32-bit devices, as building for 32-bit devices requires `ios_deployment_target` to be `10.0` or less, which per above notes dawn is not compatible with
- Per [these docs](https://gn.googlesource.com/gn/+/master/docs/reference.md#built_in-predefined-variables-target_cpu_the-desired-cpu-architecture-for-the-build-possible-values), `gn` `target_cpu` option does not have specialized support for `arm64e`, so the build the build that's in `arm64e-ios` folder is a copy of `arm64-ios`, as they are compatible with each other
- C++ API that we're making use of doesn't seem to be part of any library, but rather its own object `webgpu_cpp.o`, we copy this object manually and link against it. The issue on iOS is that this object isn't compiled with bitcode option, making it so that the app that links against it cannot use bitcode either

## Arrow (v0.17.0)

### Resources

- [cmake cross compiling for iOS](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-or-watchos)
- [arrow install instructions](https://arrow.apache.org/install/)

### Issues and solutions/workarounds

#### ./vcpkg install --triplet x64-ios arrow fails early on
As `vcpkg` iOS support is community-driven and was introduced just recently, not much time was spent trying to get this to work

#### cmake issue [#20534](https://gitlab.kitware.com/cmake/cmake/-/issues/20534)
This issue makes the build fail with valid arguments. Resolved by updating to version 3.17.2

#### cmake issue [#20588](https://gitlab.kitware.com/cmake/cmake/-/issues/20588)
This issue makes the build fail with valid arguments. Resolved by updating to version 3.17.2

#### SSE4.2 required but compiler doesn't support it
This seems to happen due to issues with signing related to cmake Xcode generator ([#18993](https://gitlab.kitware.com/cmake/cmake/-/issues/18993), [#20013](https://gitlab.kitware.com/cmake/cmake/-/issues/20013)). Solved by following the workaround from mentioned threads, and adding `set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")` to `Darwin.cmake` toolchain

#### pthread not found
This ended up being the same issue with signing. Refer to item above for solution

#### [jemalloc](https://github.com/jemalloc/jemalloc) fails compiling with `If you meant to cross compile, use --host`
There didn't seem to be an easy way to specify `host` and `target` arguments necessary for cross compiling when building `jemalloc` from source. As `jemalloc` is an optional dependency, workaround was disabling it through `-DARROW_JEMALLOC=OFF`

#### -undefined and -bitcode_bundle (Xcode setting ENABLE_BITCODE=YES) cannot be used together
As we want to have support for bitcode, this was solved by editing `BuildUtils.cmake` configuration so that it does not include `-undefined` linker flag for iOS builds

#### Undefined symbols that are part of the arrow ios.h header
Although this header contains some iOS-specific code, it looks like the implementation `.mm` file was missing. As the header was copied over from an external repo, it was a matter of copying the [implementation file](https://github.com/HowardHinnant/date/blob/master/src/ios.mm) and make it part of the build configuration

#### Undefined zlib symbols
Once `iOS.mm` file was added, there were mentions of undefined symbols related to `zlib`. This was solved by enabling the optional `zlib` dependency during configuration - `-DARROW_WITH_ZLIB=ON`

#### target specifies product type 'com.apple.product-type.tool', but there's no such product type for the 'iphoneos' platform
When using `-DARROW_JSON=ON` option, external dependency to [rapidjson](https://github.com/Tencent/rapidjson) is added. Build fails a command-line tool was trying to be built for iOS, which isn't a supported configuration. Workaround was adding `set(CMAKE_MACOSX_BUNDLE YES)` to the same `Darwin.cmake` cmake toolchain file mentioned above

#### Failed to build Boost.Build build engine
Cross compiling `Boost` does not seem to work. It was eventually resolved and built using [this script](https://github.com/faithfracture/Apple-Boost-BuildScript). As there were still issues plugging the built library back into the build process, workaround was building `arrow` without `parquet` support, which was the option that required `Boost`

Modifications to Arrow source can be found as a patch [here](/patches/arrow/arrow-iOS-build.patch).

### Building

After applying solutions and workarounds mentioned above, following commands were used to configure and build `arrow`:

```
cmake -S . -B build 
  -GXcode                                           # Use Xcode generator as suggested by cmake guide
  -DCMAKE_INSTALL_PREFIX=`pwd`/install              # Install into `install` folder within the repo
  -DCMAKE_SYSTEM_NAME=iOS                           # Cross compile for iOS
  -DCMAKE_OSX_ARCHITECTURES=armv7                   # cmake flag for specifying macOS/iOS/tvOS/watchOS architecture
                                                    # Values used for iOS: armv7, armv7s, arm64, arm64e, x86_64, i386
  -DCMAKE_OSX_SYSROOT=iphoneos                      # OS root to use for building, values used by iOS: iphoneos, iphonesimulator
  -DCMAKE_OSX_DEPLOYMENT_TARGET=9.3                 # Minimum iOS deployment target
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO       # Xcode setting that allows to build for an arbitrery architecture
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO   # Disable signing as it is not necessary
  -DARROW_JEMALLOC=OFF                              # Disable jemalloc due to issue described above
  -DARROW_WITH_ZLIB=ON                              # Enable zlib in order to enable iOS support
  -DARROW_BUILD_SHARED=OFF                          # We do not need the shared libraries
  -DARROW_JSON=ON                                   # Toggle optional JSON support on
  -DARROW_CSV=ON                                    # Toggle optional CSV support on
  -DARROW_FILESYSTEM=ON                             # Toggle optional filesystem support
  -DCMAKE_SYSTEM_PROCESSOR=armv7                    # Specify system processor explicitly in order to enable arrow CPU-based optimizations
                                                    # Relevant values: armv7, ARM64, x86
```

```
cmake --build build --config Release --target install
```

### Additional Notes

- `Xcode` generator is used in order to leverage some of the configuration `Xcode` performs automatically. `Make` also seems to work, but does not add the appropriate flag needed for `bitcode` support automatically. This can likely be supplied externally
- `cmake` has support for building multiple architectures at once, and combining the resulting libraries automatically. We do not make use of this in order to specify appropriate `CMAKE_SYSTEM_PROCESSOR` values for each specific architecture, as well as due to configuration not picking up dependencies based on whether build system is `iphoneos` or `iphonesimulator`, resulting in builds failing due to invalid linking

## shaderc (v2020.0)

### Issues and solutions/workarounds

#### Several feature checks failing during configuration
This happens due to an issue with `cmake` ([#18993](https://gitlab.kitware.com/cmake/cmake/-/issues/18993), [#20013](https://gitlab.kitware.com/cmake/cmake/-/issues/20013)), the same one encountered while building `arrow` when using `Xcode` generator. Solved by following the workaround from mentioned threads, and adding `set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")` to `Darwin.cmake` toolchain

#### install TARGETS given no BUNDLE DESTINATION for MACOSX_BUNDLE executable
Resolved by providing a DESTINATION property for BUNDLE type of resources in `install` functions wherever RUNTIME type was present. This is part of [shaderc patch](/patches/shaderc/shaderc-iOS-build.patch)

#### ../third_party/spirv-tools/tools/reduce/reduce.cpp:33:18: error: 'system' is unavailable: not available on iOS
cmake setup seems to rely on `IOS_PLATFORM` flag to exclude some iOS incompatible features, specifying `-DIOS_PLATFORM` doesn't seem to work correctly though, so the flag is just switched on as part of [shaderc patch](/patches/shaderc/shaderc-iOS-build.patch)

#### CMake Error at libshaderc/cmake_install.cmake:146 (file): file INSTALL cannot find "/libshaderc/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/libshaderc_combined.a": No such file or directory.
This shows up at the end of installation. For whatever reason, `libshaderc_combined.a` could not be found and is not copied over. However, the file is available to be picked up from `build/shaderc/[Release/Debug]-*/libshaderc_combined.a`

### Building

After applying solutions and workarounds mentioned above, following commands were used to configure and build `shaderc`:

```
cmake -S . -B build 
  -GXcode                                         # Use Xcode generator as suggested by cmake guide
  -DCMAKE_INSTALL_PREFIX=`pwd`/install            # Install into `install` folder within the repo
  -DCMAKE_SYSTEM_NAME=iOS                         # Cross compile for iOS
  "-DCMAKE_OSX_ARCHITECTURES=armv7;armv7s;arm64;arm64e" # Build for all the relevant iOS architectures
  -DCMAKE_OSX_DEPLOYMENT_TARGET=9.3               # Minimum iOS deployment target
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO     # Xcode setting that allows to build for an arbitrery architecture
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO # Disable signing as it is not necessary
  -DSHADERC_SKIP_TESTS=true                       # Skip trying to build tests
  -DIOS_PLATFORM=ON                               # Attempt at enabling IOS_PLATFORM flag
  -DSHADERC_SKIP_INSTALL=OFF                      # Do not skip installing
```

## jsoncpp (v1.9.2)

### Issues and solutions/workarounds

#### Several feature checks failing during configuration
This happens due to an issue with `cmake` ([#18993](https://gitlab.kitware.com/cmake/cmake/-/issues/18993), [#20013](https://gitlab.kitware.com/cmake/cmake/-/issues/20013)), the same one encountered while building `arrow` when using `Xcode` generator. Solved by following the workaround from mentioned threads, and adding `set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")` to `Darwin.cmake` toolchain

### Building

After applying solutions and workarounds mentioned above, following commands were used to configure and build `jsoncpp`:

```
cmake -S . -B build 
  -GXcode                                           # Use Xcode generator as suggested by cmake guide
  -DCMAKE_INSTALL_PREFIX=`pwd`/install              # Install into `install` folder within the repo
  -DCMAKE_SYSTEM_NAME=iOS                           # Cross compile for iOS
  "-DCMAKE_OSX_ARCHITECTURES=armv7;armv7s;arm64;arm64e;x86_64;i386" # Build for all the relevant iOS architectures
  -DCMAKE_OSX_DEPLOYMENT_TARGET=9.3                 # Minimum iOS deployment target
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO       # Xcode setting that allows to build for an arbitrery architecture
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO   # Disable signing as it is not necessary
  -DJSONCPP_WITH_CMAKE_PACKAGE=OFF                  # The rest of the settings are jsoncpp specific and skip unnecessary steps
  -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF
  -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
  -DJSONCPP_WITH_TESTS=OFF
```

```
cmake --build build --config Release --target install
```

## FMT (v6.2.1)

### Issues and solutions/workarounds

#### Several feature checks failing during configuration
This happens due to an issue with `cmake` ([#18993](https://gitlab.kitware.com/cmake/cmake/-/issues/18993), [#20013](https://gitlab.kitware.com/cmake/cmake/-/issues/20013)), the same one encountered while building `arrow` when using `Xcode` generator. Solved by following the workaround from mentioned threads, and adding `set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")` to `Darwin.cmake` toolchain

### Building

After applying solutions and workarounds mentioned above, following commands were used to configure and build `fmt`:

```
cmake -S . -B build 
  -GXcode                                           # Use Xcode generator as suggested by cmake guide
  -DCMAKE_INSTALL_PREFIX=`pwd`/install              # Install into `install` folder within the repo
  -DCMAKE_SYSTEM_NAME=iOS                           # Cross compile for iOS
  "-DCMAKE_OSX_ARCHITECTURES=armv7;armv7s;arm64;arm64e;x86_64;i386" # Build for all the relevant iOS architectures
  -DCMAKE_OSX_DEPLOYMENT_TARGET=9.3                 # Minimum iOS deployment target
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO       # Xcode setting that allows to build for an arbitrery architecture
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO   # Disable signing as it is not necessary
```

## range-v3

As this is a header-only library, headers were taken from `x64-osx` artifacts. The library itself builds fine for iOS with a regular set of build commands.
