cmake_minimum_required(VERSION 3.16)
project(betterkhmer C)

set(CMAKE_C_STANDARD 11)

add_library(betterkhmer STATIC src/betterkhmer.c)
target_include_directories(betterkhmer PUBLIC src)

add_executable(test_normalize test/test_normalize.c)
target_link_libraries(test_normalize betterkhmer)
