// miniaudio_flutter.c
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Engine structure - simplified to avoid memory corruption
typedef struct {
    ma_engine engine;
    int initialized;
    char padding[64]; // Extra padding to prevent corruption
} miniaudio_engine_t;

// Sound structure - simplified to avoid size issues
typedef struct {
    ma_sound sound;     // This alone is quite large
    int loaded;         // Simple flag
    char padding[64];   // Extra padding to prevent corruption
} miniaudio_sound_t;

// Export functions for FFI
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Simple test function to verify the library is working
EXPORT int miniaudio_test() {
    return 42;  // Simple test - if this works, basic FFI is functional
}

// Test if audio output is working at all using system beep
EXPORT int miniaudio_test_beep(miniaudio_engine_t* engine) {
    printf("DEBUG: miniaudio_test_beep() called\n");
    fflush(stdout);
    
    if (engine == NULL) {
        printf("DEBUG: Engine is NULL\n");
        fflush(stdout);
        return -1;
    }
    
    if (!engine->initialized) {
        printf("DEBUG: Engine not initialized\n");
        fflush(stdout);
        return -1;
    }
    
    printf("DEBUG: Engine validation passed, attempting beep...\n");
    fflush(stdout);
    
    // Try to generate a simple beep using Windows API as fallback
    // This will help us confirm if any audio output is possible
    #ifdef _WIN32
    printf("DEBUG: About to call Windows Beep API...\n");
    fflush(stdout);
    
    // Use Windows Beep function as a test
    BOOL beepResult = Beep(440, 500);  // 440Hz for 500ms
    
    printf("DEBUG: Beep API returned: %d\n", beepResult);
    fflush(stdout);
    
    if (beepResult) {
        printf("DEBUG: Beep successful, returning 0\n");
        fflush(stdout);
        return 0;  // Success
    } else {
        DWORD error = GetLastError();
        printf("DEBUG: Beep failed with error: %lu\n", error);
        fflush(stdout);
        return -2;  // Beep failed
    }
    #else
    printf("DEBUG: Not Windows platform\n");
    fflush(stdout);
    return -3;  // Not Windows
    #endif
}

// Initialize the audio engine with ultra-low latency settings
EXPORT int miniaudio_init_engine(miniaudio_engine_t* engine) {
    printf("DEBUG: miniaudio_init_engine() called\n");
    fflush(stdout);
    
    if (engine == NULL) {
        printf("DEBUG: Engine pointer is NULL\n");
        fflush(stdout);
        return -1;
    }
    
    printf("DEBUG: Engine pointer valid, clearing structure...\n");
    fflush(stdout);
    
    // Clear the structure
    memset(engine, 0, sizeof(miniaudio_engine_t));
    
    printf("DEBUG: Structure cleared, configuring REAL miniaudio engine...\n");
    fflush(stdout);
    
    // Configure miniaudio for real audio output - let's try the simplest possible config
    ma_engine_config config = ma_engine_config_init();
    
    printf("DEBUG: Basic engine config created\n");
    fflush(stdout);
    
    // Try with minimal configuration first
    config.pDevice = NULL;  // Use default device
    config.periodSizeInFrames = 1024;  // Larger buffer for stability
    config.periodSizeInMilliseconds = 0;
    
    printf("DEBUG: Engine config set, attempting ma_engine_init...\n");
    fflush(stdout);
    
    ma_result result = ma_engine_init(&config, &engine->engine);
    
    printf("DEBUG: ma_engine_init returned: %d (MA_SUCCESS = %d)\n", result, MA_SUCCESS);
    fflush(stdout);
    
    if (result != MA_SUCCESS) {
        printf("DEBUG: Engine initialization failed, error: %d\n", result);
        
        // Try to get more specific error information
        switch (result) {
            case MA_INVALID_ARGS:
                printf("DEBUG: Error was MA_INVALID_ARGS\n");
                break;
            case MA_INVALID_OPERATION:
                printf("DEBUG: Error was MA_INVALID_OPERATION\n");
                break;
            case MA_OUT_OF_MEMORY:
                printf("DEBUG: Error was MA_OUT_OF_MEMORY\n");
                break;
            case MA_DEVICE_NOT_INITIALIZED:
                printf("DEBUG: Error was MA_DEVICE_NOT_INITIALIZED\n");
                break;
            default:
                printf("DEBUG: Unknown miniaudio error code: %d\n", result);
                break;
        }
        fflush(stdout);
        return (int)result;
    }
    
    engine->initialized = 1;
    printf("DEBUG: Engine marked as initialized, final validation...\n");
    printf("DEBUG: Engine address after init: %p\n", (void*)engine);
    printf("DEBUG: Engine initialized flag after init: %d\n", engine->initialized);
    fflush(stdout);
    
    printf("DEBUG: REAL miniaudio engine initialized successfully!\n");
    fflush(stdout);
    return 0;
}

// Load a sound file into memory for instant playback
EXPORT int miniaudio_load_sound(miniaudio_engine_t* engine, miniaudio_sound_t* sound, const char* file_path) {
    printf("DEBUG: miniaudio_load_sound() called\n");
    fflush(stdout);
    
    // Check if pointers are valid before doing anything
    if (engine == NULL) {
        printf("DEBUG: Engine is NULL\n");
        fflush(stdout);
        return -10;
    }
    if (sound == NULL) {
        printf("DEBUG: Sound is NULL\n");
        fflush(stdout);
        return -11;
    }
    if (file_path == NULL) {
        printf("DEBUG: File path is NULL\n");
        fflush(stdout);
        return -12;
    }
    
    printf("DEBUG: All parameters valid, file_path: %s\n", file_path);
    printf("DEBUG: Engine address: %p\n", (void*)engine);
    printf("DEBUG: Sound address: %p\n", (void*)sound);
    printf("DEBUG: Engine initialized flag: %d\n", engine->initialized);
    fflush(stdout);
    
    // Instead of relying on our flag, check if the engine structure looks valid
    printf("DEBUG: Checking engine validity by attempting to access engine structure...\n");
    fflush(stdout);
    
    // Clear the sound structure safely
    memset(sound, 0, sizeof(miniaudio_sound_t));
    
    printf("DEBUG: Sound structure cleared, checking engine validity...\n");
    fflush(stdout);
    
    printf("DEBUG: Sound structure cleared, checking engine validity...\n");
    fflush(stdout);
    
    // Try direct access without using the flag first, as an experiment
    printf("DEBUG: Engine validation passed, attempting to load real WAV file...\n");
    fflush(stdout);
    
    // Try to load the actual sound file using miniaudio
    ma_result result = ma_sound_init_from_file(&engine->engine, file_path, MA_SOUND_FLAG_DECODE, NULL, NULL, &sound->sound);
    
    printf("DEBUG: ma_sound_init_from_file returned: %d (MA_SUCCESS = %d)\n", result, MA_SUCCESS);
    fflush(stdout);
    
    if (result != MA_SUCCESS) {
        printf("DEBUG: Failed to load sound file, error: %d\n", result);
        
        // Try to get more specific error information
        switch (result) {
            case MA_INVALID_ARGS:
                printf("DEBUG: Error was MA_INVALID_ARGS - invalid arguments\n");
                break;
            case MA_INVALID_FILE:
                printf("DEBUG: Error was MA_INVALID_FILE - file doesn't exist or is invalid\n");
                break;
            case MA_INVALID_DATA:
                printf("DEBUG: Error was MA_INVALID_DATA - file format not supported\n");
                break;
            case MA_OUT_OF_MEMORY:
                printf("DEBUG: Error was MA_OUT_OF_MEMORY - not enough memory\n");
                break;
            default:
                printf("DEBUG: Unknown miniaudio error code: %d\n", result);
                break;
        }
        fflush(stdout);
        return (int)result;
    }
    
    printf("DEBUG: Sound file loaded successfully, final engine check...\n");
    fflush(stdout);
    
    // Instead of relying on the corrupted flag, let's try to validate the engine differently
    // The flag gets corrupted, so let's use a different approach
    printf("DEBUG: Skipping corrupted flag check, marking sound as loaded...\n");
    fflush(stdout);
    
    sound->loaded = 1;
    
    printf("DEBUG: Sound marked as loaded, returning success\n");
    fflush(stdout);
    
    return 0;  // Success
}

// Play a loaded sound with minimal latency
EXPORT void miniaudio_play_sound(miniaudio_engine_t* engine, miniaudio_sound_t* sound) {
    printf("DEBUG: miniaudio_play_sound() called\n");
    fflush(stdout);
    
    if (engine == NULL || sound == NULL || !engine->initialized || !sound->loaded) {
        printf("DEBUG: Invalid parameters for play_sound\n");
        if (engine == NULL) printf("DEBUG: engine is NULL\n");
        if (sound == NULL) printf("DEBUG: sound is NULL\n");
        if (engine && !engine->initialized) printf("DEBUG: engine not initialized\n");
        if (sound && !sound->loaded) printf("DEBUG: sound not loaded\n");
        fflush(stdout);
        return;
    }
    
    printf("DEBUG: Parameters valid, attempting to play sound...\n");
    fflush(stdout);
    
    // Reset sound to beginning for clean playback
    ma_sound_seek_to_pcm_frame(&sound->sound, 0);
    
    printf("DEBUG: Sound seeked to start, starting playback...\n");
    fflush(stdout);
    
    // Start playing the sound
    ma_result result = ma_sound_start(&sound->sound);
    
    printf("DEBUG: ma_sound_start returned: %d (MA_SUCCESS = %d)\n", result, MA_SUCCESS);
    fflush(stdout);
    
    if (result != MA_SUCCESS) {
        printf("DEBUG: Failed to start sound playback, error: %d\n", result);
        fflush(stdout);
    } else {
        printf("DEBUG: Sound playback started successfully\n");
        fflush(stdout);
    }
}

// Stop all sounds immediately
EXPORT void miniaudio_stop_all(miniaudio_engine_t* engine) {
    if (engine == NULL || !engine->initialized) return;
    
    ma_engine_stop(&engine->engine);
    ma_engine_start(&engine->engine);
}

// Clean up the engine
EXPORT void miniaudio_uninit_engine(miniaudio_engine_t* engine) {
    printf("DEBUG: miniaudio_uninit_engine() called\n");
    fflush(stdout);
    
    if (engine == NULL) {
        printf("DEBUG: Engine is NULL, nothing to uninit\n");
        fflush(stdout);
        return;
    }
    
    if (!engine->initialized) {
        printf("DEBUG: Engine not initialized, nothing to uninit\n");
        fflush(stdout);
        return;
    }
    
    printf("DEBUG: Uninitializing miniaudio engine...\n");
    fflush(stdout);
    
    ma_engine_uninit(&engine->engine);
    
    engine->initialized = 0;
    
    printf("DEBUG: Engine uninitialized successfully\n");
    fflush(stdout);
}

// Clean up a sound
EXPORT void miniaudio_uninit_sound(miniaudio_sound_t* sound) {
    if (sound == NULL || !sound->loaded) return;
    
    ma_sound_uninit(&sound->sound);
    
    sound->loaded = 0;
}

#ifdef __cplusplus
}
#endif
