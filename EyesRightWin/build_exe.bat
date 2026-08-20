@echo off
setlocal
cd /d "%~dp0"

echo [1/3] Creating venv...
python -m venv .venv
call .venv\Scripts\activate.bat

echo [2/3] Installing dependencies...
python -m pip install -U pip
pip install -r requirements.txt

echo [3/3] Building with PyInstaller...
pyinstaller --noconfirm EyesRight.spec

echo.
echo Done.
echo Run: dist\EyesRight\EyesRight.exe
echo Folder dist\EyesRight can be zipped and sent to others (Win10/Win11).
pause
