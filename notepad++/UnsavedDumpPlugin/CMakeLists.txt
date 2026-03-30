cmake_minimum_required(VERSION 3.21)
project(UnsavedDumpPlugin LANGUAGES CXX)

add_library(UnsavedDumpPlugin SHARED
    src/UnsavedDumpPlugin.cpp
)

target_compile_features(UnsavedDumpPlugin PRIVATE cxx_std_17)
target_compile_definitions(UnsavedDumpPlugin PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(UnsavedDumpPlugin PRIVATE Comdlg32)

set_target_properties(UnsavedDumpPlugin PROPERTIES
    OUTPUT_NAME "UnsavedDumpPlugin"
)
