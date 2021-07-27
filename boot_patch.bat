@echo off
setlocal enabledelayedexpansion
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

:: �޲�����
:patch
echo  - Windows��ֻ���ֶ�����flag�����ò����Զ���ȡ...
echo  - ���ֶ��޸Ĺ���Ŀ¼��config.txt�ļ��󲢵������������...
timeout /t 3 /nobreak > nul
echo "ARCH=arm64">config.txt
echo "ARCH32=arm">>config.txt
echo "IS64BIT=true">>config.txt
echo "KEEPVERITY=1">>config.txt
echo "KEEPFORCEENCRYPT=1">>config.txt
notepad config.txt
pause>nul
:: ���ñ���
for /f %%i in ('type config.txt') do set %%i
echo  - �������Ϊ��
echo               ARCH:%ARCH%
echo               ARCH32:%ARCH32%
echo               IS64BIT:%IS64BIT%
echo               KEEPVERITY:%KEEPVERITY%
echo               KEEPFORCEENCRYPT:%KEEPFORCEENCRYPT%
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
pause