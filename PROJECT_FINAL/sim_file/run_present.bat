@echo off
rem =============================================================================
rem run_present.bat — 발표용 파형 TB (tb_P_present) 장면 하나 실행
rem   사용 : run_present.bat <장면 P1~P6> [wave]
rem     예 : run_present.bat P3          (콘솔만, 결과 xsim_work\tb_P_present\sim_P3.log)
rem          run_present.bat P3 wave     (xsim GUI + wcfg\present\P3.wcfg 파형, run all 까지 자동)
rem   장면은 반드시 하나씩 (장면 시작 = 0 ms 가 되어 안내서 시각과 그대로 맞음)
rem   안내서 : ahnsung\FINAL\ppt_make\top_파형_캡처_안내.md
rem   Vivado 경로가 다르면 아래 VIV 를 고칠 것
rem =============================================================================
setlocal enabledelayedexpansion
set VIV=C:\Xilinx\Vivado\2020.2\bin
set TB=tb_P_present
set SC=%1
if "%SC%"=="" (
    echo usage: run_present.bat ^<P1..P6^> [wave]
    exit /b 1
)
set WAVE=%2
set HERE=%~dp0
set SRC=%HERE%..\source_file\merge_final
set WORK=%HERE%xsim_work\%TB%
if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

set VLIST=
for %%d in (IP WTS SR04 DHT11 UART FND_LED) do (
    for %%f in ("%SRC%\%%d\*.v") do set VLIST=!VLIST! "%%~ff"
)
set SVLIST=
for %%d in (WTS UART) do (
    for %%f in ("%SRC%\%%d\*.sv") do set SVLIST=!SVLIST! "%%~ff"
)

call "%VIV%\xvlog.bat" --nolog %VLIST% "%SRC%\merge_final_top.v" > compile.log 2>&1
if errorlevel 1 ( type compile.log & exit /b 1 )
call "%VIV%\xvlog.bat" --nolog -sv %SVLIST% "%HERE%tb_merge_harness.sv" "%HERE%%TB%.sv" >> compile.log 2>&1
if errorlevel 1 ( type compile.log & exit /b 1 )
set DBG=off
if /i "%WAVE%"=="wave" set DBG=typical
call "%VIV%\xelab.bat" --nolog -debug %DBG% -s %TB%_snap work.%TB% > elab.log 2>&1
if errorlevel 1 ( type elab.log & exit /b 1 )

if /i "%WAVE%"=="wave" (
    echo run all> wave_run.tcl
    call "%VIV%\xsim.bat" %TB%_snap -gui -view "%HERE%wcfg\present\%SC%.wcfg" -tclbatch wave_run.tcl -testplusarg only_%SC%
    exit /b 0
)

call "%VIV%\xsim.bat" %TB%_snap -R --nolog -testplusarg only_%SC% > sim_%SC%.log 2>&1
type sim_%SC%.log
endlocal
