@echo off
rem =============================================================================
rem run_xsim.bat — Vivado xsim 배치 실행 (GUI 없이)
rem   사용 : run_xsim.bat <tb 이름> [시나리오 ID | all] [wave]
rem     예 : run_xsim.bat tb_A_reset
rem          run_xsim.bat tb_D_stopwatch D3
rem          run_xsim.bat tb_D_stopwatch D3 wave   (xsim GUI + wcfg\tb_D_stopwatch.wcfg 파형, run all 까지)
rem          run_xsim.bat tb_D_stopwatch all wave  (그룹 전부 + 파형)
rem   결과 : xsim_work\<tb>\sim.log (콘솔에도 출력)
rem   Vivado 경로가 다르면 아래 VIV 를 고칠 것
rem =============================================================================
setlocal enabledelayedexpansion
set VIV=C:\Xilinx\Vivado\2020.2\bin
set TB=%1
if "%TB%"=="" (
    echo usage: run_xsim.bat ^<tb name^> [scenario id]
    exit /b 1
)
set ONLY=%2
if /i "%ONLY%"=="all" set ONLY=
set WAVE=%3
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
    set PLUS=
    if not "%ONLY%"=="" set PLUS=-testplusarg only_%ONLY%
    call "%VIV%\xsim.bat" %TB%_snap -gui -view "%HERE%wcfg\%TB%.wcfg" -tclbatch wave_run.tcl !PLUS!
    exit /b 0
)

if "%ONLY%"=="" (
    call "%VIV%\xsim.bat" %TB%_snap -R --nolog > sim.log 2>&1
) else (
    call "%VIV%\xsim.bat" %TB%_snap -R --nolog -testplusarg only_%ONLY% > sim.log 2>&1
)
type sim.log
endlocal
