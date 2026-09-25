# Purpose: Build whisper.cpp from the pinned submodule, and the lasr_whisper
# shim the Dart adapter binds to.
# Inputs: WHISPER_SOURCE_DIR (the submodule), and the ggml/whisper options the
# build hook passes per target.
# Side effects: Builds shared libraries into the build directory's bin/ and
# lib/ folders, where hook/build.dart collects them.
# Notes: Driven only by hook/build.dart; see doc/en-us/platform-notes.md.

cmake_minimum_required(VERSION 3.16)
project(lasr_whisper C CXX)

set(WHISPER_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../whisper.cpp"
    CACHE PATH "the pinned whisper.cpp checkout")

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_SDL2 OFF CACHE BOOL "" FORCE)
set(WHISPER_CURL OFF CACHE BOOL "" FORCE)

# Everything lands in one folder, so the libraries find each other and the
# shim finds the backends beside itself.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# Built as part of "all", so every ggml backend module is built too: with
# GGML_BACKEND_DL nothing links against them, and ggml keeps no list of their
# target names to ask for one by one.
add_subdirectory("${WHISPER_SOURCE_DIR}" whisper)

add_library(lasr_whisper SHARED lasr_whisper.c)
target_link_libraries(lasr_whisper PRIVATE whisper ggml)
set_target_properties(lasr_whisper PROPERTIES C_VISIBILITY_PRESET hidden)

