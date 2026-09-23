@echo off
chcp 65001 >nul
cd /d "%~dp0"
if "%~1"=="" (
  echo.
  echo  把名单 CSV 文件直接拖到本窗口，然后回车
  echo  或拖到「批量修复昵称.bat」图标上
  echo.
  set /p CSV=请粘贴或拖入 CSV 路径:
) else (
  set CSV=%~1
)
if "%MIMO_PYTHON%"=="" (
  set PY=python
) else (
  set PY=%MIMO_PYTHON%
)
"%PY%" "%~dp0import_users.py" "%CSV%"
echo.
pause
