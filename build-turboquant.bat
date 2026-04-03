@echo off
setlocal EnableExtensions DisableDelayedExpansion

echo.
echo ============================================
echo  llama-cpp-turboquant Build Script
echo ============================================
echo  Builds llama-server.exe with CUDA support
echo  for Windows (Visual Studio + CUDA 12.x)
echo ============================================
echo.

REM ============================================================
REM  PREREQUISITE CHECKS
REM ============================================================
echo [CHECK] Verifying prerequisites...
echo.

REM --- Check Git ---
call :check_prereq "git" "--version" "Git" "https://git-scm.com/download/win" "Make sure to add Git to your PATH during installation."
if errorlevel 1 goto :fail_pause
echo   [OK] Git found: %PREREQ_OUTPUT%
echo.

REM --- Check CMake ---
call :check_prereq "cmake" "--version" "CMake" "https://cmake.org/download/" "During installation, select 'Add CMake to the system PATH'."
if errorlevel 1 goto :fail_pause
for /f "tokens=1-3" %%a in ("%PREREQ_OUTPUT%") do set CMAKE_VER=%%a %%b %%c
echo   [OK] CMake found: %CMAKE_VER%
echo.

REM --- Check Visual Studio ---
call :find_visual_studio
if errorlevel 1 goto :fail_pause
echo   [OK] Visual Studio found: %VS_INSTALL_PATH%
echo   [OK] MSVC tools available.
echo.

REM --- Check CUDA ---
call :find_cuda
if errorlevel 1 goto :fail_pause
echo   [OK] CUDA Toolkit found: %CUDA_VERSION_STR%
echo.

REM --- Check NVIDIA GPU (informational) ---
call :detect_gpu
echo.
echo ============================================
echo  All prerequisites satisfied.
echo ============================================
echo.

REM ============================================================
REM  REPOSITORY SETUP
REM ============================================================
cd /d "%~dp0"

if not exist "llama-cpp-turboquant" (
    echo [SETUP] Cloning repository...
    git clone https://github.com/TheTom/llama-cpp-turboquant.git
    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to clone repository. Check your internet connection.
        echo.
        goto :fail_pause
    )
    echo [OK] Repository cloned.
    echo.
)

cd llama-cpp-turboquant

echo [1/4] Pulling latest updates...
git pull
if errorlevel 1 (
    echo [ERROR] Git pull failed. Check your network connection.
    echo.
    goto :fail_pause
)
echo   [OK] Repository updated.
echo.

echo [2/4] Initializing git submodules...
git submodule update --init --recursive
if errorlevel 1 (
    echo   [WARN] Submodule update had issues, continuing...
) else (
    echo   [OK] Submodules initialized.
)
echo.

REM ============================================================
REM  BUILD
REM ============================================================
if exist "build\CMakeCache.txt" (
    echo [INFO] Existing build found. Doing incremental build (faster^).
    echo   To force a full clean rebuild, run:  rmdir /s /q build   then re-run this script.
    echo.
)

echo [3/4] Configuring build with CMake...
echo   Backend:        CUDA
echo   Generator:      Visual Studio 17 2022
echo   Architectures:  86;89;120a;121a
echo   Build type:     Release
echo.

cmake -B build -DGGML_CUDA=ON -DGGML_NATIVE=OFF -DCMAKE_CUDA_ARCHITECTURES=86;89;120a;121a -G "Visual Studio 17 2022"
if errorlevel 1 (
    echo.
    echo [ERROR] CMake configuration failed!
    echo   Possible causes: missing dependencies, corrupt CMake cache.
    echo   Try re-running and choosing Y to clean the build.
    echo.
    goto :fail_pause
)
echo   [OK] CMake configuration complete.
echo.

echo [4/4] Building Release configuration...
echo   First build may take 20-60 minutes (CUDA compilation is slow).
echo   Using %NUMBER_OF_PROCESSORS% parallel jobs.
echo   Subsequent builds will be much faster.
echo.

set "MSBUILD_EXE=MSBuild"
where MSBuild >nul 2>&1 || (
    for /f "usebackq tokens=* delims=" %%m in (`"%VSWHERE_EXE%" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe 2^>nul`) do set "MSBUILD_EXE=%%m"
)
echo   Building... (output suppressed, check return code)
"%MSBUILD_EXE%" build\ALL_BUILD.vcxproj /p:Configuration=Release /p:Platform=x64 /m:%NUMBER_OF_PROCESSORS% /nologo /v:q > "%TEMP%\llama-build.log" 2>&1
set BUILD_RC=%ERRORLEVEL%
if %BUILD_RC% EQU 0 (
    echo   Build completed successfully.
) else (
    type "%TEMP%\llama-build.log" | findstr /I "error"
)
del /q "%TEMP%\llama-build.log" >nul 2>&1
echo.
if %BUILD_RC% NEQ 0 (
    echo [ERROR] Build failed!
    echo   Run this to see full output:
    echo     msbuild build\ALL_BUILD.vcxproj /p:Configuration=Release /v:normal
    echo.
    goto :fail_pause
)
echo   [OK] Build complete.
echo.

REM ============================================================
REM  POST-BUILD
REM ============================================================
setlocal EnableDelayedExpansion
echo ============================================
echo  Build Successful!
echo ============================================
echo.

if exist "build\bin\Release\llama-server.exe" (
    for %%F in ("build\bin\Release\llama-server.exe") do set FSIZE=%%~zF
    echo [OK] llama-server.exe built successfully
    echo     Size: !FSIZE! bytes
    echo.
    echo Other built tools:
    if exist "build\bin\Release\llama-cli.exe"         echo   llama-cli.exe         - Command-line inference
    if exist "build\bin\Release\llama-quantize.exe"    echo   llama-quantize.exe    - Model quantization
    if exist "build\bin\Release\llama-bench.exe"       echo   llama-bench.exe       - Performance benchmark
    if exist "build\bin\Release\llama-imatrix.exe"     echo   llama-imatrix.exe     - Importance matrix
    echo.
    echo ============================================
    echo  Example usage:
    echo ============================================
    echo.
    echo build\bin\Release\llama-server.exe --models-dir C:\Users\Paulhome\llama\models\ --fit on --ctx-size 40000 --port 8080 --host 0.0.0.0 --temp 0.6 --top-p 0.95 --min-p 0.00 --sleep-idle-seconds 300 --jinja --flash-attn on --repeat-penalty 1.0 --threads 6 --threads-batch 12 --cache-type-k q8_0 --cache-type-v q8_0 -ot "ffn_gate_exps=CPU","ffn_up_exps=CPU","ffn_down_exps=CPU" -np 1 --batch-size 1024 --ubatch-size 256 --timeout 3600 --models-max 1 --mlock --poll 1
    echo.
) else (
    echo [WARN] llama-server.exe not found in build output!
    echo   Check: %~dp0llama-cpp-turboquant\build\bin\Release\
    echo.
)

echo ============================================
echo  To rebuild in the future, just run this script again.
echo ============================================
echo.
pause
exit /b 0

REM ============================================================
REM  FUNCTIONS
REM ============================================================

:check_prereq
REM   %1=command name  %2=version args  %3=friendly name  %4=download URL  %5=install tip
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [FAIL] %~3 is not installed or not in your PATH.
    echo.
    echo   Download from: %~4
    echo   %~5
    echo   Then re-run this script.
    echo.
    exit /b 1
)
for /f "tokens=1-3 delims= " %%a in ('%~1 %~2 2^>nul ^| findstr /R "^[a-zA-Z]"') do (
    set "PREREQ_OUTPUT=%%a %%b %%c"
    goto :prereq_done
)
:prereq_done
if not defined PREREQ_OUTPUT (
    echo [FAIL] %~3 found but version check failed.
    exit /b 1
)
exit /b 0

:find_visual_studio
set VS_FOUND=0
set VS_INSTALL_PATH=

REM Method 1: vswhere (use temp file to avoid for/f backtick issues)
set "VSWHERE_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE_EXE%" (
    "%VSWHERE_EXE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%TEMP%\vswhere_out.tmp" 2>nul
    set /p VS_INSTALL_PATH= < "%TEMP%\vswhere_out.tmp" 2>nul
    if exist "%TEMP%\vswhere_out.tmp" del "%TEMP%\vswhere_out.tmp" 2>nul
    if defined VS_INSTALL_PATH set VS_FOUND=1
)

REM Method 2: scan common directories
if %VS_FOUND% EQU 0 (
    call :scan_vs_paths
)
if %VS_FOUND% EQU 0 (
    echo [FAIL] Visual Studio 2019+ with "Desktop development with C++" not found.
    echo.
    echo   Download from: https://visualstudio.microsoft.com/downloads/
    echo   Select workload "Desktop development with C++" during install.
    echo   Then re-run this script.
    echo.
    exit /b 1
)
exit /b 0

:scan_vs_paths
for %%D in (C D E F G H) do (
    for %%V in (
        "%%D:\Program Files\Microsoft Visual Studio\2022\Community"
        "%%D:\Program Files\Microsoft Visual Studio\2022\Professional"
        "%%D:\Program Files\Microsoft Visual Studio\2022\Enterprise"
        "%%D:\Program Files\Microsoft Visual Studio\2022\Insiders"
        "%%D:\Program Files\Microsoft Visual Studio\2022\Preview"
        "%%D:\Program Files\Microsoft Visual Studio\2019\Community"
        "%%D:\Program Files\Microsoft Visual Studio\2019\Professional"
        "%%D:\Program Files\Microsoft Visual Studio\2019\Enterprise"
        "%%D:\Program Files\Microsoft Visual Studio\2019\Preview"
        "%%D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
        "%%D:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools"
    ) do (
        if exist "%%~V\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_INSTALL_PATH=%%~V"
            set VS_FOUND=1
            exit /b 0
        )
    )
)
exit /b 0

:find_cuda
set CUDA_FOUND=0
set CUDA_PATH=
set CUDA_VERSION_STR=

REM Check environment variable
if defined CUDA_PATH (
    if exist "%CUDA_PATH%\bin\nvcc.exe" (
        set CUDA_FOUND=1
        for %%F in ("%CUDA_PATH%") do set CUDA_VERSION_STR=%%~nxF
        goto cuda_done
    )
)

REM Check known versions on default path
set "CUDA_BASE=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
call :check_cuda_ver v12.9
call :check_cuda_ver v12.8
call :check_cuda_ver v12.7
call :check_cuda_ver v12.6
call :check_cuda_ver v12.5
call :check_cuda_ver v12.4
call :check_cuda_ver v12.3
call :check_cuda_ver v12.2
call :check_cuda_ver v12.1
call :check_cuda_ver v12.0
call :check_cuda_ver v11.8

:cuda_done
if %CUDA_FOUND% EQU 0 (
    echo [FAIL] CUDA Toolkit not found.
    echo.
    echo   Download from: https://developer.nvidia.com/cuda-toolkit
    echo   This project supports CUDA 12.x.
    echo   After installation, re-run this script.
    echo.
    exit /b 1
)
exit /b 0

:check_cuda_ver
REM   %1 = version string like v12.9
if exist "%CUDA_BASE%\%~1\bin\nvcc.exe" (
    set "CUDA_PATH=%CUDA_BASE%\%~1"
    set CUDA_VERSION_STR=%~1
    set CUDA_FOUND=1
)
exit /b 0

:detect_gpu
where nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo   [INFO] nvidia-smi not found - skipping GPU detection
    exit /b 0
)
for /f "tokens=* delims=" %%g in ('nvidia-smi --query-gpu^=name --format^=csv^,noheader 2^>nul ^| findstr /v "not"') do (
    echo   [OK] NVIDIA GPU detected: %%g
    goto :eof
)
echo   [INFO] No NVIDIA GPU detected via nvidia-smi
exit /b 0

:fail_pause
pause
exit /b 1
