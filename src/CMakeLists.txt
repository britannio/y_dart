# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(y_dart_library VERSION 0.0.1 LANGUAGES C)

add_library(y_dart SHARED
  "y_dart.c"
)

set_target_properties(y_dart PROPERTIES
  PUBLIC_HEADER y_dart.h
  OUTPUT_NAME "y_dart"
)

target_compile_definitions(y_dart PUBLIC DART_SHARED_LIB)
