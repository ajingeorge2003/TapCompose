cmake_minimum_required(VERSION 3.16)
project(miniaudio_flutter)

set(CMAKE_CXX_STANDARD 11)

# Add the miniaudio C file
add_library(miniaudio_flutter SHARED
    miniaudio_flutter.c
)

# Set compiler flags for optimization and low latency
if(WIN32)
    target_compile_definitions(miniaudio_flutter PRIVATE
        MA_WIN32=1
        MA_NO_WASAPI=0
        MA_NO_DSOUND=1
        MA_NO_WINMM=1
    )
    target_link_libraries(miniaudio_flutter 
        winmm
        ole32
        user32
        advapi32
        shell32
    )
    set_target_properties(miniaudio_flutter PROPERTIES
        OUTPUT_NAME "miniaudio_flutter"
        SUFFIX ".dll"
    )
elseif(APPLE)
    target_compile_definitions(miniaudio_flutter PRIVATE
        MA_OSX=1
        MA_NO_COREAUDIO=0
    )
    target_link_libraries(miniaudio_flutter
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework AudioUnit"
        "-framework CoreFoundation"
    )
    if(IOS)
        set_target_properties(miniaudio_flutter PROPERTIES
            OUTPUT_NAME "miniaudio_flutter"
            SUFFIX ".dylib"
        )
    else()
        set_target_properties(miniaudio_flutter PROPERTIES
            OUTPUT_NAME "libminiaudio_flutter"
            SUFFIX ".dylib"
        )
    endif()
elseif(UNIX AND NOT APPLE)
    target_compile_definitions(miniaudio_flutter PRIVATE
        MA_LINUX=1
        MA_NO_ALSA=0
        MA_NO_PULSEAUDIO=0
        MA_NO_JACK=1
    )
    target_link_libraries(miniaudio_flutter
        asound
        pulse
        pulse-simple
        pthread
        m
        dl
    )
    set_target_properties(miniaudio_flutter PROPERTIES
        OUTPUT_NAME "libminiaudio_flutter"
        SUFFIX ".so"
    )
endif()

# Optimization flags for low latency
target_compile_options(miniaudio_flutter PRIVATE
    -O3
    -ffast-math
    -march=native
    -mtune=native
)

# Include current directory for miniaudio.h
target_include_directories(miniaudio_flutter PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Install to Flutter project's platform-specific directories
if(WIN32)
    install(TARGETS miniaudio_flutter 
        DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../windows/runner/
    )
elseif(APPLE)
    if(IOS)
        install(TARGETS miniaudio_flutter 
            DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../ios/Runner/
        )
    else()
        install(TARGETS miniaudio_flutter 
            DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../macos/Runner/
        )
    endif()
elseif(UNIX)
    install(TARGETS miniaudio_flutter 
        DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../linux/runner/
    )
endif()
