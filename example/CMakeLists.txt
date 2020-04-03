cmake_minimum_required(VERSION 3.12)

set(DEPS_ROOT "" CACHE PATH "Root for dependencies")

set(CMAKE_CXX_STANDARD 17)

project(deck.gl-native-dependencies LANGUAGES C CXX)

set(ALL_SOURCE_FILES
    test.cpp
    )

include_directories(${DEPS_ROOT}/include)
find_library(jsoncpp_LIB jsoncpp PATHS ${DEPS_ROOT}/lib NO_DEFAULT_PATH)
find_library(gtest_LIB gtest PATHS ${DEPS_ROOT}/lib NO_DEFAULT_PATH)

add_executable(example ${ALL_SOURCE_FILES})
target_link_libraries(example PUBLIC ${jsoncpp_LIB} ${gtest_LIB} pthread)

# Testing
enable_testing()
include(GoogleTest)

gtest_discover_tests(example)
