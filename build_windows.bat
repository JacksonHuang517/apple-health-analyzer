@echo off
chcp 65001
echo ===========================
echo  健康骑行分析器 Windows 构建
echo ===========================
echo.

REM 创建虚拟环境
python -m venv venv
call venv\Scripts\activate.bat

REM 安装依赖
pip install pyinstaller -i https://mirrors.aliyun.com/pypi/simple/

REM 构建 exe
pyinstaller --name "HealthCyclingAnalyzer" ^
  --windowed ^
  --add-data "dashboard.html;." ^
  --hidden-import tkinter ^
  --hidden-import tkinter.filedialog ^
  --hidden-import tkinter.messagebox ^
  --clean -y ^
  HealthCyclingAnalyzer.py

echo.
echo 构建完成！exe 位于 dist\HealthCyclingAnalyzer\ 目录
pause
