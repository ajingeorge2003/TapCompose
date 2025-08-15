// miniaudio_bindings.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Define C structs and function signatures for miniaudio
final class MiniaudioEngine extends Struct {
  // Reserve enough space for the actual miniaudio engine struct
  // ma_engine + ma_device + ma_context + int is likely ~1000+ bytes
  @Array(256) // 256 * 8 = 2048 bytes should be more than enough
  external Array<Uint64> data;
}

final class MiniaudioSound extends Struct {
  // Reserve enough space for the actual miniaudio sound struct
  // ma_sound + ma_decoder are HUGE structures (several KB each)
  // Let's allocate much more space to prevent memory corruption
  @Array(1024) // 1024 * 8 = 8192 bytes (8KB) - much larger buffer
  external Array<Uint64> data;
}

// Function type definitions
typedef MiniaudioTestNative = Int32 Function();
typedef MiniaudioTest = int Function();

typedef MiniaudioTestBeepNative = Int32 Function(Pointer<MiniaudioEngine> engine);
typedef MiniaudioTestBeep = int Function(Pointer<MiniaudioEngine> engine);

typedef MiniaudioInitEngineNative = Int32 Function(Pointer<MiniaudioEngine> engine);
typedef MiniaudioInitEngine = int Function(Pointer<MiniaudioEngine> engine);

typedef MiniaudioLoadSoundNative = Int32 Function(
    Pointer<MiniaudioEngine> engine, 
    Pointer<MiniaudioSound> sound, 
    Pointer<Utf8> filePath
);
typedef MiniaudioLoadSound = int Function(
    Pointer<MiniaudioEngine> engine, 
    Pointer<MiniaudioSound> sound, 
    Pointer<Utf8> filePath
);

typedef MiniaudioPlaySoundNative = Void Function(
    Pointer<MiniaudioEngine> engine, 
    Pointer<MiniaudioSound> sound
);
typedef MiniaudioPlaySound = void Function(
    Pointer<MiniaudioEngine> engine, 
    Pointer<MiniaudioSound> sound
);

typedef MiniaudioStopAllNative = Void Function(Pointer<MiniaudioEngine> engine);
typedef MiniaudioStopAll = void Function(Pointer<MiniaudioEngine> engine);

typedef MiniaudioUninitEngineNative = Void Function(Pointer<MiniaudioEngine> engine);
typedef MiniaudioUninitEngine = void Function(Pointer<MiniaudioEngine> engine);

class MiniaudioBindings {
  static DynamicLibrary? _library;
  
  // Function pointers
  static MiniaudioTest? _test;
  static MiniaudioTestBeep? _testBeep;
  static MiniaudioInitEngine? _initEngine;
  static MiniaudioLoadSound? _loadSound;
  static MiniaudioPlaySound? _playSound;
  static MiniaudioStopAll? _stopAll;
  static MiniaudioUninitEngine? _uninitEngine;

  static bool _isLoaded = false;

  static bool loadLibrary() {
    if (_isLoaded) return true;

    try {
      // Load platform-specific library
      if (Platform.isWindows) {
        _library = DynamicLibrary.open('miniaudio_flutter.dll');
      } else if (Platform.isLinux) {
        _library = DynamicLibrary.open('libminiaudio_flutter.so');
      } else if (Platform.isMacOS) {
        _library = DynamicLibrary.open('libminiaudio_flutter.dylib');
      } else if (Platform.isAndroid) {
        _library = DynamicLibrary.open('libminiaudio_flutter.so');
      } else if (Platform.isIOS) {
        _library = DynamicLibrary.process();
      } else {
        print('❌ MINIAUDIO: Unsupported platform');
        return false;
      }

      // Load function pointers
      _test = _library!
          .lookup<NativeFunction<MiniaudioTestNative>>('miniaudio_test')
          .asFunction();
          
      _testBeep = _library!
          .lookup<NativeFunction<MiniaudioTestBeepNative>>('miniaudio_test_beep')
          .asFunction();
          
      _initEngine = _library!
          .lookup<NativeFunction<MiniaudioInitEngineNative>>('miniaudio_init_engine')
          .asFunction();

      _loadSound = _library!
          .lookup<NativeFunction<MiniaudioLoadSoundNative>>('miniaudio_load_sound')
          .asFunction();

      _playSound = _library!
          .lookup<NativeFunction<MiniaudioPlaySoundNative>>('miniaudio_play_sound')
          .asFunction();

      _stopAll = _library!
          .lookup<NativeFunction<MiniaudioStopAllNative>>('miniaudio_stop_all')
          .asFunction();

      _uninitEngine = _library!
          .lookup<NativeFunction<MiniaudioUninitEngineNative>>('miniaudio_uninit_engine')
          .asFunction();

      _isLoaded = true;
      print('✅ MINIAUDIO: Library loaded successfully');
      return true;
    } catch (e) {
      print('❌ MINIAUDIO: Failed to load library: $e');
      return false;
    }
  }

  static int test() {
    if (!_isLoaded || _test == null) return -1;
    return _test!();
  }

  static int testBeep(Pointer<MiniaudioEngine> engine) {
    if (!_isLoaded || _testBeep == null) return -1;
    return _testBeep!(engine);
  }

  static int initEngine(Pointer<MiniaudioEngine> engine) {
    if (!_isLoaded || _initEngine == null) return -1;
    return _initEngine!(engine);
  }

  static int loadSound(Pointer<MiniaudioEngine> engine, Pointer<MiniaudioSound> sound, String filePath) {
    if (!_isLoaded || _loadSound == null) return -1;
    final pathPtr = filePath.toNativeUtf8();
    final result = _loadSound!(engine, sound, pathPtr);
    malloc.free(pathPtr);
    return result;
  }

  static void playSound(Pointer<MiniaudioEngine> engine, Pointer<MiniaudioSound> sound) {
    if (!_isLoaded || _playSound == null) return;
    _playSound!(engine, sound);
  }

  static void stopAll(Pointer<MiniaudioEngine> engine) {
    if (!_isLoaded || _stopAll == null) return;
    _stopAll!(engine);
  }

  static void uninitEngine(Pointer<MiniaudioEngine> engine) {
    if (!_isLoaded || _uninitEngine == null) return;
    _uninitEngine!(engine);
  }
}
