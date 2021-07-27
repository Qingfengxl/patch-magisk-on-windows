@echo off
setlocal enabledelayedexpansion
set adb=tools\platform-tools\adb.exe
set magiskboot=tools\magiskboot\magiskboot.exe
set busybox=tools\busybox\busybox.exe
set bootimage=%1
if not defined bootimage (
echo  - ���� - ��û��ָ��boot����...
call :usage
echo  - ������˳�...
pause>nul 
exit /b 1
) else (
echo  - ָ��boot�ļ�Ϊ��!bootimage! ...
echo  - ���ڼ���ļ��Ƿ����...
if not exist !bootimage! echo  - ���� - δ���ҵ�boot�ļ�...&call :usage&echo  - ������˳�...&pause>nul&exit
goto :patch
)
:usage
echo  - Usage:
echo  -       boot_patch.bat boot.img
goto :eof

:get_dir
echo  - ��ȡ�ļ�����·��...
echo  - �� "%~dp0" ��Ϊ����·��...
cd %~dp0
goto :eof

:ui_print
echo  - %1
goto :eof

:abort
echo  - %1
echo  - ���������޷�����...
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

:: �޲�����
:patch
for /F %%i in ('!adb! get-state') do set state=%%i
if /I "!state!"=="device" (
echo  - ��⵽���ӵ��˰�׿�豸...
echo  - ���ڴ��豸�л�ȡ������Ϣ...
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
echo  - �����Ϣ�����̶�...
for /F %%i in ('type config.txt') do set %%i
if not defined ARCH echo  - �������ô�������������������Ϣ...&pause&call :make_config
if not defined ARCH32 echo  - �������ô�������������������Ϣ...&pause&call :make_config
if not defined IS64BIT echo  - �������ô�������������������Ϣ...&pause&call :make_config
if not defined KEEPVERITY echo  - �������ô�������������������Ϣ...&pause&call :make_config
if not defined KEEPFORCEENCRYPT echo  - �������ô�������������������Ϣ...&pause&call :make_config
) else (
echo  - ������û�������ֻ��������Զ���ȡ�豸��Ϣ��ֻ���ֶ�����flag������...
echo  - ���ֶ��޸Ĺ���Ŀ¼��config.txt�ļ��󲢵������������...
timeout /t 3 /nobreak > nul
call :make_config
notepad config.txt
pause>nul
)
:: ���ñ���
if exist "config.txt" for /f %%i in ('type config.txt') do set %%i
echo  - �������Ϊ��
echo               ARCH:%ARCH%
echo               ARCH32:%ARCH32%
echo               IS64BIT:%IS64BIT%
echo               KEEPVERITY:%KEEPVERITY%
echo               KEEPFORCEENCRYPT:%KEEPFORCEENCRYPT%
echo  - ׼���ļ�
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
echo  - ��ʼ�޲�boot.img
timeout /t 3 /nobreak > nul
echo  - ���boot...
!magiskboot! --unpack !bootimage!
if "!errorlevel!"=="0" echo  - �������...
if "!errorlevel!"=="1" echo  - δ֪�����ʽ...
if "!errorlevel!"=="2" echo  - ����ChromeOS boot�����ʽ...&echo  - ���ź�windows����޲����򻹲�֧���������...&call :abort ����Գ������ֻ����޲�...
if "!errorlevel!"=="*" call :abort δ֪����...
echo  - ���ramdisk.cpio
!magiskboot! --cpio ramdisk.cpio test
if "!errorlevel!"=="0" ( echo  - ��⵽δ�����޸ĵ�boot����...
for /f %%i in ('tools\magiskboot\magiskboot.exe --sha1 boot_a.img') do set SHA1=%%i
copy "!bootimage!" "stock_boot.img"
!busybox! cp -af ramdisk.cpio ramdisk.cpio.orig
)
if "!errorlevel!"=="1" ( echo  - ��⵽��Magisk �޲�����boot����...
if not defined SHA1 !magiskboot! --cpio ramdisk.cpio sha1
!magiskboot! --cpio ramdisk.cpio restore
!busybox! cp -af ramdisk.cpio ramdisk.cpio.orig
!busybox! rm -f stock_boot.img
)
if "!errorlevel!"=="2" ( echo  - ��⵽��֧�ֵ�boot����...
echo  - boot���񱻲�֧�ֵĳ����޲���...
call :abort ��ʹ�ùٷ���boot����...
)
echo  - �޲�ramdisk.cpio...
:: ת���ļ�����ʡ����ramdisk�ռ�(ԭ����ע�;�����ôд��)
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
:: �������޲�
for %%i in (dtb,kernel_dtb,extra) do (
if exist "%%i" ( !magiskboot! --dtb-patch %%i
echo ���ڶ�%%i�޲�fstab
)
)
if exist "kernel" (
:: �Ƴ����ǵ�RKP
!magiskboot! --hexpatch kernel 49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054 A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054
:: �Ƴ�����defex
!magiskboot! --hexpatch kernel 821B8012 E2FF8F12
:: ǿ���ں�ʹ��rootfs
!magiskboot! --hexpatch kernel 736B69705F696E697472616D667300 77616E745F696E697472616D667300
)
echo  - ���ڴ��boot...
!magiskboot! --repack !bootimage!
!magiskboot! --cleanup
if exist new-boot.img (
echo  - �ļ����ɳɹ���
echo  - ���patch���...
!magiskboot! --unpack new-boot.img
!magiskboot! --cpio ramdisk.cpio test
if "!errorlevel!"=="1" ( echo  - ��⵽magisk �޲�...
) else (
echo  - δ��⵽magisk �޲�...
)
!magiskboot! --cleanup
if exist "magiskinit" del /q "magiskinit"
if exist "magisk32" del /q "magisk32"
if exist "magisk64" del /q "magisk64"
if exist "config.txt" del /q "config.txt"
)
pause