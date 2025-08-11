import 'dart:ffi';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';
import 'miniaudio_bindings.dart';

class AudioService {
  // Native engine and sound storage
  Pointer<MiniaudioEngine>? _engine;
  final Map<String, Pointer<MiniaudioSound>> _sounds = {};
  bool _isInitialized = false;

  /// Initializes miniaudio with ultra-low latency settings optimized for real-time drum sequencing
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🎵 MINIAUDIO: Initializing ultra-low latency audio engine...');

      // Load the miniaudio native library
      if (!MiniaudioBindings.loadLibrary()) {
        print('❌ MINIAUDIO: Failed to load native library');
        // Fallback to a stub implementation for development
        _isInitialized = true;
        print('⚠️  MINIAUDIO: Running in stub mode - build native library for real audio');
        return;
      }

      print('✅ MINIAUDIO: Library loaded successfully');

      // Test basic FFI functionality
      try {
        print('DEBUG: About to test basic FFI functionality...');
        final testResult = MiniaudioBindings.test();
        print('✅ MINIAUDIO: Basic FFI test passed, result: $testResult');
      } catch (e) {
        print('❌ MINIAUDIO: Basic FFI test failed: $e');
        _isInitialized = true;
        print('⚠️  MINIAUDIO: Running in stub mode - FFI test failed');
        return;
      }

      // Check if we already have an engine allocated
      if (_engine != null) {
        print('❌ MINIAUDIO: Engine already allocated! This might cause a memory leak');
        print('DEBUG: Freeing existing engine before allocating new one');
        malloc.free(_engine!);
        _engine = null;
      }

      // Allocate engine
      print('DEBUG: About to allocate engine memory...');
      _engine = malloc<MiniaudioEngine>();
      if (_engine == null) {
        print('❌ MINIAUDIO: Failed to allocate engine memory');
        return;
      }
      print('✅ MINIAUDIO: Engine memory allocated at address: ${_engine!.address}');

      // Initialize the engine
      print('DEBUG: About to initialize engine...');
      final result = MiniaudioBindings.initEngine(_engine!);
      print('DEBUG: Engine initialization returned: $result');
      
      if (result != 0) {
        print('❌ MINIAUDIO: Engine initialization failed with code: $result');
        _freeEngine();
        return;
      }

      _isInitialized = true;
      print('✅ MINIAUDIO: Ultra-low latency audio engine initialized successfully!');
      print('🚀 MINIAUDIO: Ready for real-time audio playback');
      print('DEBUG: AudioService initialization completed successfully');
      print('DEBUG: Final engine address after init: ${_engine!.address}');
      
      // Give the audio engine a moment to fully initialize
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      print('❌ MINIAUDIO: Initialization error: $e');
      _freeEngine();
      // Fall back to stub mode
      _isInitialized = true;
      print('⚠️  MINIAUDIO: Running in stub mode due to error');
    }
  }

  /// Loads a single sound from assets into memory for instant playback
  Future<void> loadSound(String assetPath) async {
    if (!_isInitialized || _engine == null) {
      print('⚠️  MINIAUDIO: Engine not initialized, cannot load: $assetPath');
      return;
    }

    try {
      print('🔄 MINIAUDIO: Loading sound: $assetPath');
      print('DEBUG: Current loaded sounds count: ${_sounds.length}');
      print('DEBUG: Engine address at start of loadSound: ${_engine!.address}');
      
      // Copy asset to temporary file for native access
      File? tempFile;
      try {
        tempFile = await _copyAssetToTemp(assetPath);
        if (tempFile == null) {
          print('❌ MINIAUDIO: Failed to copy asset to temp file: $assetPath');
          return;
        }
        print('✅ MINIAUDIO: Asset copied to temp file: ${tempFile.path}');
      } catch (e) {
        print('❌ MINIAUDIO: Error copying asset to temp: $e');
        return;
      }

      // Allocate sound structure
      final sound = malloc<MiniaudioSound>();
      print('✅ MINIAUDIO: Sound structure allocated');

      // Load the sound with error handling
      try {
        print('DEBUG: About to call MiniaudioBindings.loadSound()...');
        print('DEBUG: Engine address: ${_engine!.address}');
        print('DEBUG: Sound address: ${sound.address}');
        print('DEBUG: File path: ${tempFile.path}');
        
        final result = MiniaudioBindings.loadSound(_engine!, sound, tempFile.path);
        
        print('DEBUG: MiniaudioBindings.loadSound() returned: $result');
        
        if (result != 0) {
          print('❌ MINIAUDIO: Failed to load sound with code $result: $assetPath');
          print('DEBUG: Freeing sound memory due to load failure');
          malloc.free(sound);
          return;
        }
        print('✅ MINIAUDIO: Native sound loading successful');
      } catch (e) {
        print('❌ MINIAUDIO: Native sound loading error: $e');
        print('DEBUG: Exception details: ${e.toString()}');
        print('DEBUG: Exception stack trace: ${StackTrace.current}');
        print('⚠️  MINIAUDIO: Continuing without this sound to prevent crash');
        try {
          malloc.free(sound);
        } catch (freeError) {
          print('DEBUG: Error freeing sound memory: $freeError');
        }
        return;
      }

      // Store the loaded sound
      _sounds[assetPath] = sound;
      print('✅ MINIAUDIO: Loaded sound for ultra-low latency playback: $assetPath');
    } catch (e) {
      print('❌ MINIAUDIO: Error loading sound $assetPath: $e');
    }
  }

  /// Plays a pre-loaded sound with minimal latency (< 6ms)
  void playSound(String assetPath) {
    if (!_isInitialized || _engine == null) {
      print('⚠️  MINIAUDIO: Engine not initialized, cannot play: $assetPath');
      return;
    }

    final sound = _sounds[assetPath];
    if (sound == null) {
      print('❌ MINIAUDIO: Sound not loaded: $assetPath');
      return;
    }

    try {
      // Play with minimal latency
      MiniaudioBindings.playSound(_engine!, sound);
      print('🔊 MINIAUDIO: Playing sound: $assetPath');
    } catch (e) {
      print('❌ MINIAUDIO: Error playing sound $assetPath: $e');
    }
  }

  /// Plays multiple sounds simultaneously with minimal latency
  /// This is optimized for drum machine patterns where multiple instruments
  /// need to play at exactly the same time
  void playMultiple(List<String> assetPaths) {
    if (!_isInitialized || _engine == null) {
      print('⚠️  MINIAUDIO: Engine not initialized, cannot play multiple sounds');
      return;
    }

    try {
      // Play all sounds in rapid succession for near-simultaneous playback
      for (final assetPath in assetPaths) {
        final sound = _sounds[assetPath];
        if (sound != null) {
          MiniaudioBindings.playSound(_engine!, sound);
        } else {
          print('❌ MINIAUDIO: Sound not loaded in multiple play: $assetPath');
        }
      }
      print('🔊 MINIAUDIO: Playing ${assetPaths.length} sounds simultaneously');
    } catch (e) {
      print('❌ MINIAUDIO: Error playing multiple sounds: $e');
    }
  }

  /// Stops all currently playing sounds immediately
  void stopAllSounds() {
    if (!_isInitialized || _engine == null) return;

    try {
      MiniaudioBindings.stopAll(_engine!);
      print('⏹️  MINIAUDIO: All sounds stopped');
    } catch (e) {
      print('❌ MINIAUDIO: Error stopping sounds: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    print('🧹 MINIAUDIO: Cleaning up audio resources...');

    // Free all loaded sounds
    for (final sound in _sounds.values) {
      malloc.free(sound);
    }
    _sounds.clear();

    // Free engine
    _freeEngine();

    _isInitialized = false;
    print('✅ MINIAUDIO: Audio service disposed');
  }

  void _freeEngine() {
    print('DEBUG: _freeEngine() called');
    if (_engine != null) {
      print('DEBUG: Engine exists, cleaning up...');
      print('DEBUG: Engine address before cleanup: ${_engine!.address}');
      try {
        print('DEBUG: Calling MiniaudioBindings.uninitEngine()...');
        MiniaudioBindings.uninitEngine(_engine!);
        print('DEBUG: uninitEngine() completed successfully');
      } catch (e) {
        print('⚠️  MINIAUDIO: Error during engine cleanup: $e');
        print('DEBUG: Cleanup exception details: ${e.toString()}');
      }
      
      print('DEBUG: Freeing engine memory...');
      malloc.free(_engine!);
      _engine = null;
      print('DEBUG: Engine memory freed and pointer nulled');
    } else {
      print('DEBUG: Engine is null, nothing to free');
    }
    print('DEBUG: _freeEngine() completed');
  }

  /// Copy asset to temporary file so native code can access it
  Future<File?> _copyAssetToTemp(String assetPath) async {
    try {
      // Load asset data
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();

      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/miniaudio_$fileName');

      // Write asset data to temp file
      await tempFile.writeAsBytes(bytes);
      
      print('📄 MINIAUDIO: Copied asset to temp file: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      print('❌ MINIAUDIO: Error copying asset to temp: $e');
      return null;
    }
  }

  // Test if audio output is working
  Future<void> testBeep() async {
    print('DEBUG: testBeep() called');
    print('DEBUG: _isInitialized: $_isInitialized');
    print('DEBUG: _engine != null: ${_engine != null}');
    
    if (!_isInitialized || _engine == null) {
      print('❌ MINIAUDIO: Cannot test beep - engine not initialized');
      return;
    }

    try {
      print('🔊 MINIAUDIO: Testing audio output with system beep...');
      print('DEBUG: Engine address: ${_engine!.address}');
      print('DEBUG: About to call MiniaudioBindings.testBeep()...');
      
      final result = MiniaudioBindings.testBeep(_engine!);
      
      print('DEBUG: testBeep returned: $result');
      
      if (result == 0) {
        print('✅ MINIAUDIO: System beep test successful!');
      } else {
        print('❌ MINIAUDIO: System beep test failed with code: $result');
      }
    } catch (e) {
      print('❌ MINIAUDIO: Error during beep test: $e');
      print('DEBUG: Exception details: ${e.toString()}');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }
    
    print('DEBUG: testBeep() completed');
  }

  // Getters for monitoring
  bool get isInitialized => _isInitialized;
  int get loadedSoundsCount => _sounds.length;
}

