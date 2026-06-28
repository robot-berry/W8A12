@echo off
setlocal
set REPO=%~dp0..\..
pushd "%REPO%"
set VIVADO=D:\software\2025.2\Vivado\bin\vivado.bat
set TCL=%REPO%\W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_accel_top_ooc.tcl
set OUTDIR=%REPO%\W8A12_3lane\evidence\top\accel_top_ooc
set LOG=%OUTDIR%\vivado_accel_top_ooc.log
set JOU=%OUTDIR%\vivado_accel_top_ooc.jou
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
"%VIVADO%" -mode batch -log "%LOG%" -journal "%JOU%" -source "%TCL%" > "%OUTDIR%\vivado_accel_top_ooc.stdout.txt" 2>&1
set RC=%ERRORLEVEL%
if "%RC%"=="0" (
  python "%REPO%\W8A12_3lane\tools\summarize_ooc_result.py" --tag accel_top --report-dir "%OUTDIR%"
  set RC=%ERRORLEVEL%
)
popd
exit /b %RC%
