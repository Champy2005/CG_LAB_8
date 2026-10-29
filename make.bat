@echo off
setlocal enabledelayedexpansion
where cmake >nul 2>&1 || set "PATH=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\vcpkg\installed\x64-windows\bin;C:\VulkanSDK\1.4.357.0\Bin;%PATH%"
if not defined CMAKE_PREFIX_PATH set "CMAKE_PREFIX_PATH=C:\vcpkg\installed\x64-windows"
set BUILD=build
set TARGET=%1

if "%TARGET%"=="" set TARGET=all
if "%TARGET%"=="clean" (
  if exist "%BUILD%" rmdir /s /q "%BUILD%"
  exit /b 0
)

cmake -S . -B %BUILD% -DCMAKE_BUILD_TYPE=Release || exit /b 1

if "%TARGET%"=="all" (
  cmake --build %BUILD% --config Release || exit /b 1
  exit /b 0
)

cmake --build %BUILD% --config Release --target %TARGET% || exit /b 1

set EXE=%BUILD%\%TARGET%.exe
if exist "%BUILD%\Release\%TARGET%.exe" set EXE=%BUILD%\Release\%TARGET%.exe
if not exist "!EXE!" (
  echo could not find !EXE!
  exit /b 1
)
echo running !EXE!
"!EXE!" %2 %3 %4 %5 %6 %7 %8 %9
