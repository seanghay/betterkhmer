cmake_minimum_required(VERSION 3.16)
project(betterkhmer CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(PkgConfig REQUIRED)
pkg_check_modules(PCRE2 REQUIRED libpcre2-8)

add_library(betterkhmer STATIC src/betterkhmer.cpp)
target_include_directories(betterkhmer PUBLIC src ${PCRE2_INCLUDE_DIRS})
target_link_libraries(betterkhmer ${PCRE2_LIBRARIES})
target_compile_options(betterkhmer PRIVATE ${PCRE2_CFLAGS_OTHER})

add_executable(test_normalize test/test_normalize.cpp)
target_link_libraries(test_normalize betterkhmer)
