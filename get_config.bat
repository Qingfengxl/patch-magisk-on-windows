@echo off
echo  - ���Դ��ֻ��л�ȡ��Ϣ...
setlocal enabledelayedexpansion
for /F %%i in ('adb shell getprop ro.product.cpu.abi') do (
set abi=%%i
if /I "!abi:~0,5!"=="arm64" (
echo "ARCH=arm64"
echo "ARCH32=arm"
echo "IS64BIT=true"
) >config.txt
if /I "!abi:~0,7!"=="armeabi" (
echo "ARCH=arm"
echo "ARCH32=arm"
echo "IS64BIT=false"
) >config.txt
if /I "!abi:~0,3!"=="x86" (
echo "ARCH=x86"
echo "ARCH32=x86"
echo "IS64BIT=false"
) > config.txt
if /I "!abi:~0,6!"=="x86_64" (
echo "ARCH=x64"
echo "ARCH32=x86"
echo "IS64BIT=true"
) > config.txt
)
for /F %%i in ('adb shell getprop ro.build.system_root_image') do set sar=%%i
if "%sar%"=="true" ( echo "KEEPVERITY=1" >> config.txt
) else (
echo "KEEPVERITY=1" >> config.txt
) 
for /F %%i in ('adb shell getprop ro.crypto.state') do set encrypt=%%i
if "%encrypt%"=="unencrypted" ( echo "KEEPFORCEENCRYPT=0" >> config.txt
) else (
echo "KEEPFORCEENCRYPT=1" >> config.txt
) 
echo  - �����Ϣ�����̶�...
for /F %%i in ('type config.txt') do set %%i
if not defined ARCH echo  - �����ļ���������������������Ϣ...&pause&exit /b 1
if not defined ARCH32 echo  - �����ļ���������������������Ϣ...&pause&exit /b 1
if not defined IS64BIT echo  - �����ļ���������������������Ϣ...&pause&exit /b 1
if not defined KEEPVERITY echo  - �����ļ���������������������Ϣ...&pause&exit /b 1
if not defined KEEPFORCEENCRYPT echo  - �����ļ���������������������Ϣ...&pause&exit /b 1
