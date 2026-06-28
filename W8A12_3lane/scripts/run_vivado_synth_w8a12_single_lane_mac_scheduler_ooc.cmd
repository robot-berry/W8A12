@echo off
setlocal
set REPO=%~dp0..\..
pushd "%REPO%"
set VIVADO=D:\software\2025.2\Vivado\bin\vivado.bat
set TCL=%REPO%\W8A12_3lane\scripts\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.tcl
set OUTDIR=%REPO%\W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc
set LOG=%OUTDIR%\vivado_single_lane_mac_scheduler_ooc.log
set JOU=%OUTDIR%\vivado_single_lane_mac_scheduler_ooc.jou
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
"%VIVADO%" -mode batch -log "%LOG%" -journal "%JOU%" -source "%TCL%" > "%OUTDIR%\vivado_single_lane_mac_scheduler_ooc.stdout.txt" 2>&1
set RC=%ERRORLEVEL%
if "%RC%"=="0" (
  python "%REPO%\W8A12_3lane\tools\summarize_ooc_result.py" --tag single_lane --report-dir "%OUTDIR%"
  set RC=%ERRORLEVEL%
)
popd
exit /b %RC%
