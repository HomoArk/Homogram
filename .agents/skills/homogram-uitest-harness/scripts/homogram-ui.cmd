@echo off
setlocal
set SCRIPT_DIR=%~dp0
where uv >nul 2>nul
if %ERRORLEVEL%==0 (
  uv run python "%SCRIPT_DIR%homogram_ui_harness.py" %*
  exit /b %ERRORLEVEL%
)
where python3 >nul 2>nul
if %ERRORLEVEL%==0 (
  python3 "%SCRIPT_DIR%homogram_ui_harness.py" %*
  exit /b %ERRORLEVEL%
)
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%SCRIPT_DIR%homogram_ui_harness.py" %*
  exit /b %ERRORLEVEL%
)
python "%SCRIPT_DIR%homogram_ui_harness.py" %*
exit /b %ERRORLEVEL%
