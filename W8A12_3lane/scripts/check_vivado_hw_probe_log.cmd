@echo off
setlocal
cd /d "%~dp0\..\.."
python W8A12_3lane\tools\check_vivado_hw_probe_log.py %*
exit /b %ERRORLEVEL%
