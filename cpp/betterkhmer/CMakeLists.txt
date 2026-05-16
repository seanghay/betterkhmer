cmake_minimum_required(VERSION 3.16)
project(betterkhmer CXX)

set(CMAKE_CXX_STANDARD 17)

add_library(betterkhmer STATIC src/betterkhmer.cpp)
target_include_directories(betterkhmer PUBLIC src)

add_executable(test_normalize test/test_normalize.cpp)
target_link_libraries(test_normalize betterkhmer)
