## =============================================================================
##  top_sr04 constraints (Basys3) - 10/29 수업 구성
##  HC-SR04 <-> Pmod JA (보드 정면 기준 왼쪽 위 커넥터, 윗줄)
##    JA1 (J1) : TRIG   (FPGA -> sensor)
##    JA2 (L2) : ECHO   (sensor -> FPGA)
##    Pin 5    : GND
##    Pin 6    : VCC 3.3V
##  * 전원 끈 상태에서 연결할 것 (ESD), VCC/GND 반대로 꽂으면 센서 손상
##  * 켠 뒤 센서가 뜨거우면 쇼트 -> 즉시 전원 OFF
## =============================================================================

## Clock 100MHz
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## 7 Segment Display
set_property -dict { PACKAGE_PIN W7  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[0]}]
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[1]}]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[2]}]
set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[3]}]
set_property -dict { PACKAGE_PIN U5  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[4]}]
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[5]}]
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[6]}]
set_property -dict { PACKAGE_PIN V7  IOSTANDARD LVCMOS33 } [get_ports {fnd_font[7]}]
set_property -dict { PACKAGE_PIN U2  IOSTANDARD LVCMOS33 } [get_ports {fnd_com[0]}]
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports {fnd_com[1]}]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports {fnd_com[2]}]
set_property -dict { PACKAGE_PIN W4  IOSTANDARD LVCMOS33 } [get_ports {fnd_com[3]}]

## Buttons
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst]
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports btnR]

set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btnU]   ;# 자동 측정 ON (UART 명령 대용, 단독 테스트용)

## Switch SW15 : 거리 막대 LED ON/OFF
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports sw_led]

## LEDs : LD0~7 거리 막대 / LD8 측정 중 / LD9 측정 오류
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]

## Pmod Header JA
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports trig];  #Sch name = JA1
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports echo];  #Sch name = JA2

## echo 는 비동기 외부 입력 -> 타이밍 분석 제외 (내부 2-FF synchronizer 로 처리)
set_false_path -from [get_ports echo]
