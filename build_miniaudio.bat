@echo off
REM Build script for miniaudio native library on Windows
REM This script downloads miniaudio.h and builds the native library

echo Building miniaudio native library for TapCompose...

cd /d "%~dp0"
cd native

echo.
echo Step 1: Downloading miniaudio.h...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mackron/miniaudio/master/miniaudio.h' -OutFile 'miniaudio.h'"

if not exist miniaudio.h (
    echo ERROR: Failed to download miniaudio.h
    pause
    exit /b 1
)

echo miniaudio.h downloaded successfully!

echo.
echo Step 2: Creating build directory...
if not exist build mkdir build
cd build

echo.
echo Step 3: Running CMake...
cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++

if %errorlevel% neq 0 (
    echo ERROR: CMake configuration failed
    echo Make sure you have CMake and MinGW installed
    pause
    exit /b 1
)

echo.
echo Step 4: Building the library...
cmake --build . --config Release

if %errorlevel% neq 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo Step 5: Installing library to Flutter project...
cmake --install .

if %errorlevel% neq 0 (
    echo ERROR: Install failed
    pause
    exit /b 1
)

echo.
echo ✅ SUCCESS: miniaudio native library built successfully!
echo The library has been installed to the appropriate Flutter platform directory.
echo.
echo You can now run your Flutter app with ultra-low latency audio!
echo.

pause
