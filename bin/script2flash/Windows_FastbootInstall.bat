@echo off&setlocal enabledelayedexpansion
title Chao mung den voi Error OS Flash Tool
cd %~dp0
set fastboot=META-INF\fastboot
set /p DeviceCodeRom=<META-INF\Data\DeviceCode
echo.
echo.[i] - Doc thong tin truoc khi flash
echo.
echo.1. ROM nay can bootloader da unlock! Neu chua, vui long dong cua so nay lai.
echo.2. Flash ROM se MAT TOAN BO DU LIEU! Kiem tra ky truoc khi bam.
echo.3. Day la ROM FREE! Neu ban thay ai ban ROM nay, hay bao admin ngay.
echo.4. Chung toi KHONG chiu trach nhiem neu may ban bi loi/brick sau khi flash.
echo.5. Bam dung ROM cua may ban - sai se brick.
echo.
echo.[i] - Neu ban da hieu, nhan phim bat ky de vao tool.
echo.[i] - Neu khong thi dong cua so nay.
pause >NUL 2>NUL
echo.=========================================================================================
echo. Chon che do format truoc khi flash
echo.
echo.   y = Format toan bo Data (Flash sach - mat het du lieu)
echo.   n = Giu du lieu (Dirty flash - khong mat du lieu)
echo.
echo.=========================================================================================
set /p CHOICE="Lua chon cua ban {y/n}: "
echo.=========================================================================================
echo.Ket noi dien thoai vao PC + boot vao Fastboot mode
echo.Neu khong nhan thay may - bam nut tang/giam am luong de fastboot reload
echo.Va cai lai driver
echo.=========================================================================================

for /f "tokens=2" %%a in ('!fastboot! getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set DeviceCodeReal=%%a
for /f "tokens=2" %%a in ('!fastboot! getvar slot-count 2^>^&1 ^| findstr /l /b /c:"slot-count:"') do set fqlx=%%a
if "!fqlx!" == "2" (set fqlx=AB)  else (set fqlx=A)

if "!DeviceCodeReal!" == "mars" set DeviceCodeReal=star

echo !DeviceCodeReal! | findstr /b /c:"!DeviceCodeRom!"  >nul 2>nul 
if errorlevel 1 (
    title Loi: May dich khac ROM! & echo. May ban la "!DeviceCodeReal!".  ROM nay cho "!DeviceCodeRom!". & pause & exit /B 1
)

for /f %%i in ('dir /b *.img.zst') do (
 	set par=%%i
 	set par=!par:.img.zst=!
 	del /s /q !par!.img >nul 2>nul 
 	echo.  Dang giai nen !par! ...
   	META-INF\zstd -d !par!.img.zst -o !par!.img
)

for /f %%i in ('dir /b images') do (
	set par=%%~ni
	set url=images\%%i
	if !par! == cust ( 
		!fastboot! flash !par! !url!  >nul 2>nul 
	) else if !par! == preloader_raw (
		!fastboot! flash preloader_a !url! >nul 2>nul 
		!fastboot! flash preloader_b !url! >nul 2>nul 
		!fastboot! flash preloader1 !url! >nul 2>nul 
		!fastboot! flash preloader2 !url! >nul 2>nul 
	) else if !fqlx! == AB ( 
		!fastboot! flash !par!_a !url!
		!fastboot! flash !par!_b !url!
	) else ( 
		!fastboot! flash !par! !url!
	)
)

if exist super.img (
        !fastboot! flash super super.img
        del /s /q super.img >nul 2>nul 
)

if /I "%CHOICE%" == "y" (
	echo.  Dang format toan bo Data... (5-10 phut, may se dung hoai)
	!fastboot! erase frp  >NUL 2>NUL
	!fastboot! erase userdata  >NUL 2>NUL
        !fastboot! erase metadata  >NUL 2>NUL
	echo.
)

echo.  Done. May se tu khoi dong lai sau giay phut...
echo.  Lan dau boot co the mat 10-30 phut (toi uu he thong)
echo.  Dung dung lai may trong qua trinh nay
echo.
if !fqlx! == AB (!fastboot! set_active a  >NUL 2>NUL)
!fastboot! reboot 
pause
exit
