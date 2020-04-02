cmake_minimum_required(VERSION 3.12)

set(CMAKE_CXX_STANDARD 17)

project(deck.gl-native-dependencies LANGUAGES C CXX)

set(ALL_SOURCE_FILES
    test.cpp
    )

add_executable(example ${ALL_SOURCE_FILES})

target_include_directories(example PUBLIC ${DEPS_ROOT}/include)
target_link_directories(example PUBLIC ${DEPS_ROOT}/lib)

# Testing
enable_testing()
include(GoogleTest)

target_link_libraries(example PUBLIC jsoncpp gtest pthread)

gtest_discover_tests(example)
