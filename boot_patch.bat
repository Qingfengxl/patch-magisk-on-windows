@echo off
setlocal enabledelayedexpansion
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

:: 修补镜像
:patch
echo  - Windows版只能手动进行flag的设置不能自动读取...
echo  - 请手动修改工作目录下config.txt文件后并单击任意键继续...
timeout /t 3 /nobreak > nul
echo "ARCH=arm64">config.txt
echo "ARCH32=arm">>config.txt
echo "IS64BIT=true">>config.txt
echo "KEEPVERITY=1">>config.txt
echo "KEEPFORCEENCRYPT=1">>config.txt
notepad config.txt
pause>nul
:: 设置变量
for /f %%i in ('type config.txt') do set %%i
echo  - 你的设置为：
echo               ARCH:%ARCH%
echo               ARCH32:%ARCH32%
echo               IS64BIT:%IS64BIT%
echo               KEEPVERITY:%KEEPVERITY%
echo               KEEPFORCEENCRYPT:%KEEPFORCEENCRYPT%
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
pause