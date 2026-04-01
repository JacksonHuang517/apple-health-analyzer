@echo off
chcp 65001
echo ===========================
echo  Apple Health Analyzer - Windows Build
echo ===========================
echo.

REM 创建虚拟环境
python -m venv venv
call venv\Scripts\activate.bat

REM 安装依赖
pip install pyinstaller customtkinter tkinterdnd2 -i https://mirrors.aliyun.com/pypi/simple/

REM 获取 customtkinter 路径
for /f "tokens=*" %%i in ('python -c "import customtkinter, os; print(os.path.dirname(customtkinter.__file__))"') do set CTK_PATH=%%i

REM 构建 exe
pyinstaller --name "Apple Health Analyzer" ^
  --windowed ^
  --add-data "dashboard.html;." ^
  --add-data "%CTK_PATH%;customtkinter" ^
  --hidden-import tkinter ^
  --hidden-import tkinter.filedialog ^
  --hidden-import tkinter.messagebox ^
  --hidden-import customtkinter ^
  --hidden-import darkdetect ^
  --clean -y ^
  HealthCyclingAnalyzer.py

echo.
echo Build complete! exe is in dist\Apple Health Analyzer\ directory
pause
