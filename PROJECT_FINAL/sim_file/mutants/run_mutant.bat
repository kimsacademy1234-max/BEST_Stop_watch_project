@echo off
rem =============================================================================
rem run_mutant.bat <버그 ID> <tb> [시나리오 ID | all] [wave] — mutants\<ID> 소스 사본으로 그룹 TB 실행
rem     예 : mutants\run_mutant.bat M4 tb_D_stopwatch D1
rem          mutants\run_mutant.bat M4 tb_D_stopwatch D1 wave  (xsim GUI + wcfg\group\tb_D_stopwatch.wcfg 파형)
rem   버그 목록 : mutants\list.txt (ID · tb · 시나리오) — 전부 돌리기 : mutants/run_all.sh
rem   결과 : xsim_work\mut_<ID>\sim.log (콘솔에도 출력, run_all.sh 는 mutants\logs\<ID>.log 로 저장)
rem   Vivado 경로가 다르면 아래 VIV 를 고칠 것
rem =============================================================================
setlocal enabledelayedexpansion
set VIV=C:\Xilinx\Vivado\2020.2\bin
rem %~dp0 는 shift 전에 잡아야 함 (shift 하면 %0 도 밀림)
set MUT=%~dp0
set MID=%1
shift
set TB=%1
if "%TB%"=="" (
    echo usage: run_mutant.bat ^<bug id^> ^<tb name^> [scenario id]
    exit /b 1
)
set ONLY=%2
if /i "%ONLY%"=="all" set ONLY=
set WAVE=%3
set HERE=%MUT%..\
set SRC=%MUT%%MID%
set WORK=%HERE%xsim_work\mut_%MID%
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
call "%VIV%\xvlog.bat" --nolog -sv %SVLIST% "%HERE%top_tb\tb_merge_harness.sv" "%HERE%top_tb\group\%TB%.sv" >> compile.log 2>&1
if errorlevel 1 ( type compile.log & exit /b 1 )
set DBG=off
if /i "%WAVE%"=="wave" set DBG=typical
call "%VIV%\xelab.bat" --nolog -debug %DBG% -s %TB%_snap work.%TB% > elab.log 2>&1
if errorlevel 1 ( type elab.log & exit /b 1 )

if /i "%WAVE%"=="wave" (
    echo run all> wave_run.tcl
    set PLUS=
    if not "%ONLY%"=="" set PLUS=-testplusarg only_%ONLY%
    call "%VIV%\xsim.bat" %TB%_snap -gui -view "%HERE%wcfg\group\%TB%.wcfg" -tclbatch wave_run.tcl !PLUS!
    exit /b 0
)

if "%ONLY%"=="" (
    call "%VIV%\xsim.bat" %TB%_snap -R --nolog > sim.log 2>&1
) else (
    call "%VIV%\xsim.bat" %TB%_snap -R --nolog -testplusarg only_%ONLY% > sim.log 2>&1
)
type sim.log
endlocal
