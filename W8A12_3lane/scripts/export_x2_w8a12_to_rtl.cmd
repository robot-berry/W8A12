@echo off
setlocal
set REPO=%~dp0..\..
pushd "%REPO%"
set OUTDIR=%REPO%\W8A12_3lane\evidence\x2\w8a12_export
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO%\W8A12_3lane\scripts\export_x2_w8a12_to_rtl.ps1" > "%OUTDIR%\export_x2_w8a12_to_rtl.stdout.txt" 2>&1
set RC=%ERRORLEVEL%
if "%RC%"=="0" (
  python "%REPO%\W8A12_3lane\tools\check_x2_w8a12_export.py"
  set RC=%ERRORLEVEL%
)
popd
exit /b %RC%
