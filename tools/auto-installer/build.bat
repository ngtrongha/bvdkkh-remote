@echo off
setlocal
cd /d "%~dp0"

echo [1/2] Dang tim trinh bien dich C# (csc.exe)...
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

if not exist "%CSC%" (
    echo [ERROR] Khong tim thay csc.exe tren he thong!
    exit /b 1
)

echo [2/2] Dang bien dich BVDKKH-Remote-AutoInstall.exe (Che do do hoa GUI - WinExe)...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32icon:..\..\res\icon.ico /r:System.Windows.Forms.dll /r:System.Drawing.dll /win32manifest:app.manifest /out:BVDKKH-Remote-AutoInstall.exe Program.cs

if %ERRORLEVEL% equ 0 (
    copy /y BVDKKH-Remote-AutoInstall.exe ..\..\BVDKKH-Remote-AutoInstall.exe >nul
    echo.
    echo =======================================================
    echo   [SUCCESS] Da tao thanh cong file GUI:
    echo   %~dp0BVDKKH-Remote-AutoInstall.exe
    echo   ..\..\BVDKKH-Remote-AutoInstall.exe
    echo =======================================================
) else (
    echo [ERROR] Bien dich that bai!
    exit /b %ERRORLEVEL%
)
