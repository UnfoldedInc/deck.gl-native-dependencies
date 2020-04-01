cmake_minimum_required(VERSION 3.12)

set(CMAKE_CXX_STANDARD 17)

project(deck.gl-native-dependencies LANGUAGES C CXX)

find_package(jsoncpp CONFIG REQUIRED)  # C++ JSON parser
find_package(range-v3 CONFIG REQUIRED) # C++20 ranges on C++ 17.
find_package(fmt CONFIG REQUIRED)      # C++20 fmt on C++17. Link w/ fmt::fmt or fmt::fmt-header-only

set(ALL_SOURCE_FILES
    test.cpp
    )

add_executable(example ${ALL_SOURCE_FILES})

# Testing
enable_testing()
find_package(GTest CONFIG REQUIRED)
include(GoogleTest)

target_link_libraries(example PUBLIC jsoncpp_lib range-v3::range-v3 fmt::fmt GTest::gtest)

gtest_discover_tests(example)
