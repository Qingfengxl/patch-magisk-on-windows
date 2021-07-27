@echo off
setlocal enabledelayedexpansion
set adb=tools\platform-tools\adb.exe
set magiskboot=tools\magiskboot\magiskboot.exe
set busybox=tools\busybox\busybox.exe
set bootimage=%1
if not defined bootimage (
echo  - 错误 - 你没有指定boot镜像...
call :usage
echo  - 任意键退出...
pause>nul 
exit /b 1
) else (
echo  - 指定boot文件为：!bootimage! ...
echo  - 正在检测文件是否存在...
if not exist !bootimage! echo  - 错误 - 未能找到boot文件...&call :usage&echo  - 任意键退出...&pause>nul&exit
goto :patch
)
:usage
echo  - Usage:
echo  -       boot_patch.bat boot.img
goto :eof

:get_dir
echo  - 获取文件工作路径...
echo  - 将 "%~dp0" 作为工作路径...
cd %~dp0
goto :eof

:ui_print
echo  - %1
goto :eof

:abort
echo  - %1
echo  - 遇到问题无法继续...
pause
exit /b 1

:make_config
if defined ARCH ( echo "ARCH=!ARCH!">config.txt
) else (
echo "ARCH=">config.txt
)
if defined ARCH32 ( echo "ARCH32=!ARCH32!">>config.txt
) else (
echo "ARCH32=">>config.txt
)
if defined IS64BIT ( echo "IS64BIT=!IS64BIT!">>config.txt
) else (
echo "IS64BIT=ture/false">>config.txt
)
if defined KEEPVERITY ( echo "KEEPVERITY=!KEEPVERITY!">>config.txt
) else (
echo "KEEPVERITY=">>config.txt
)
if defined KEEPFORCEENCRYPT ( echo "KEEPFORCEENCRYPT=!KEEPFORCEENCRYPT!">>config.txt
) else (
echo "KEEPFORCEENCRYPT=">>config.txt
)
goto :eof

:: 修补镜像
:patch
for /F %%i in ('!adb! get-state') do set state=%%i
if /I "!state!"=="device" (
echo  - 检测到连接到了安卓设备...
echo  - 正在从设备中获取配置信息...
for /F %%i in ('adb shell getprop ro.product.cpu.abi') do (
set abi=%%i
if /I "!abi:~0,5!"=="arm64" (
set "ARCH=arm64"
set "ARCH32=arm"
set "IS64BIT=true"
)
if /I "!abi:~0,7!"=="armeabi" (
set "ARCH=arm"
set "ARCH32=arm"
set "IS64BIT=false"
)
if /I "!abi:~0,3!"=="x86" (
set "ARCH=x86"
set "ARCH32=x86"
set "IS64BIT=false"
)
if /I "!abi:~0,6!"=="x86_64" (
set "ARCH=x64"
set "ARCH32=x86"
set "IS64BIT=true"
)
)
for /F %%i in ('adb shell getprop ro.build.system_root_image') do set sar=%%i
if "!sar!"=="true" ( set "KEEPVERITY=1"
) else (
set "KEEPVERITY=1"
) 
for /F %%i in ('adb shell getprop ro.crypto.state') do set encrypt=%%i
if "!encrypt!"=="unencrypted" ( set "KEEPFORCEENCRYPT=0"
) else (
set "KEEPFORCEENCRYPT=1"
) 
echo  - 检测信息完整程度...
for /F %%i in ('type config.txt') do set %%i
if not defined ARCH echo  - 错误，配置错误，请自行输入配置信息...&pause&call :make_config
if not defined ARCH32 echo  - 错误，配置错误，请自行输入配置信息...&pause&call :make_config
if not defined IS64BIT echo  - 错误，配置错误，请自行输入配置信息...&pause&call :make_config
if not defined KEEPVERITY echo  - 错误，配置错误，请自行输入配置信息...&pause&call :make_config
if not defined KEEPFORCEENCRYPT echo  - 错误，配置错误，请自行输入配置信息...&pause&call :make_config
) else (
echo  - 由于你没有连接手机，不能自动读取设备信息，只能手动进行flag的设置...
echo  - 请手动修改工作目录下config.txt文件后并单击任意键继续...
timeout /t 3 /nobreak > nul
call :make_config
notepad config.txt
pause>nul
)
:: 设置变量
if exist "config.txt" for /f %%i in ('type config.txt') do set %%i
echo  - 你的设置为：
echo               ARCH:%ARCH%
echo               ARCH32:%ARCH32%
echo               IS64BIT:%IS64BIT%
echo               KEEPVERITY:%KEEPVERITY%
echo               KEEPFORCEENCRYPT:%KEEPFORCEENCRYPT%
echo  - 准备文件
if /I "!ARCH32!"=="arm" (
copy "arm\magiskinit" "magiskinit"
copy "arm\magisk32" "magisk32"
copy "arm\magisk64" "magisk64"
)
if /I "!ARCH32!"=="x86" (
copy "x86\magiskinit" "magiskinit"
copy "x86\magisk32" "magisk32"
copy "x86\magisk64" "magisk64"
)
echo  - 开始修补boot.img
timeout /t 3 /nobreak > nul
echo  - 解包boot...
!magiskboot! --unpack !bootimage!
if "!errorlevel!"=="0" echo  - 解包正常...
if "!errorlevel!"=="1" echo  - 未知镜像格式...
if "!errorlevel!"=="2" echo  - 发现ChromeOS boot镜像格式...&echo  - 很遗憾windows版的修补程序还不支持这个镜像...&call :abort 你可以尝试在手机上修补...
if "!errorlevel!"=="*" call :abort 未知错误...
echo  - 检测ramdisk.cpio
!magiskboot! --cpio ramdisk.cpio test
if "!errorlevel!"=="0" ( echo  - 检测到未经过修改的boot镜像...
for /f %%i in ('tools\magiskboot\magiskboot.exe --sha1 boot_a.img') do set SHA1=%%i
copy "!bootimage!" "stock_boot.img"
!busybox! cp -af ramdisk.cpio ramdisk.cpio.orig
)
if "!errorlevel!"=="1" ( echo  - 检测到被Magisk 修补过的boot镜像...
if not defined SHA1 !magiskboot! --cpio ramdisk.cpio sha1
!magiskboot! --cpio ramdisk.cpio restore
!busybox! cp -af ramdisk.cpio ramdisk.cpio.orig
!busybox! rm -f stock_boot.img
)
if "!errorlevel!"=="2" ( echo  - 检测到不支持的boot镜像...
echo  - boot镜像被不支持的程序修补了...
call :abort 请使用官方的boot镜像...
)
echo  - 修补ramdisk.cpio...
:: 转换文件来节省珍贵的ramdisk空间(原来的注释就是这么写的)
!magiskboot! --compress=xz magisk32 magisk32.xz
!magiskboot! --compress=xz magisk64 magisk64.xz
if "!IS64BIT!"=="true" set "SKIP64=rem"
!magiskboot! --cpio ramdisk.cpio "add 0750 init magiskinit"
!magiskboot! --cpio ramdisk.cpio "mkdir 0750 overlay.d"
!magiskboot! --cpio ramdisk.cpio "mkdir 0750 overlay.d/sbin"
!magiskboot! --cpio ramdisk.cpio "add 0644 overlay.d/sbin/magisk32.xz magisk32.xz"
!SKIP64! !magiskboot! --cpio ramdisk.cpio "add 0644 overlay.d/sbin/magisk64.xz magisk64.xz"
!magiskboot! --cpio ramdisk.cpio "patch !KEEPVERITY! !KEEPFORCEENCRYPT!"
!magiskboot! --cpio ramdisk.cpio "backup ramdisk.cpio.orig !SHA1!"
!magiskboot! --cpio ramdisk.cpio "mkdir 000 .backup"
!magiskboot! --cpio ramdisk.cpio "add 000 .backup/.magisk config"

!busybox! rm -f ramdisk.cpio.orig config magisk*.xz
:: 二进制修补
for %%i in (dtb,kernel_dtb,extra) do (
if exist "%%i" ( !magiskboot! --dtb-patch %%i
echo 正在对%%i修补fstab
)
)
if exist "kernel" (
:: 移除三星的RKP
!magiskboot! --hexpatch kernel 49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054 A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054
:: 移除三星defex
!magiskboot! --hexpatch kernel 821B8012 E2FF8F12
:: 强制内核使用rootfs
!magiskboot! --hexpatch kernel 736B69705F696E697472616D667300 77616E745F696E697472616D667300
)
echo  - 正在打包boot...
!magiskboot! --repack !bootimage!
!magiskboot! --cleanup
if exist new-boot.img (
echo  - 文件生成成功！
echo  - 检测patch情况...
!magiskboot! --unpack new-boot.img
!magiskboot! --cpio ramdisk.cpio test
if "!errorlevel!"=="1" ( echo  - 检测到magisk 修补...
) else (
echo  - 未检测到magisk 修补...
)
!magiskboot! --cleanup
if exist "magiskinit" del /q "magiskinit"
if exist "magisk32" del /q "magisk32"
if exist "magisk64" del /q "magisk64"
if exist "config.txt" del /q "config.txt"
)
pause