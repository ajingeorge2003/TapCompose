cmake_minimum_required(VERSION 3.18.1)

project(miniaudio_flutter)

# Include the miniaudio header from the native directory
set(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native")
include_directories(${NATIVE_DIR})

# Add the library
add_library(
    miniaudio_flutter
    SHARED
    ${NATIVE_DIR}/miniaudio_flutter.c
)

# Find and link log library
find_library(log-lib log)

# Link the library with the log library
target_link_libraries(
    miniaudio_flutter
    ${log-lib}
)
