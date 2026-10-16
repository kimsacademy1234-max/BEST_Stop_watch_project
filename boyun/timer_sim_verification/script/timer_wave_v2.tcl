# 타이머 TB 파형 자동 배치 (verification_v2 02_timer 안내서 단계 1~11 순서)
# 사용: 시뮬레이션 창 Tcl Console 에서
#   source C:/Users/LG/Developer/Lec_verilog/Mini_Project_watch/timer_wave_v2.tcl
#   (이 PC 는 restart 하면 Vivado 가 튕김 → 저장 후 Relaunch Simulation, 그다음) run all
# TB 이름은 지금 시뮬레이션의 최상위를 자동으로 씀 (tb_tm_1 / tb_tm_2 / tb_tm_3 어느 것이든)
# 색: 빨강 · 파랑 안 씀 (김창형 교수님 규칙 — Vivado 는 X 를 빨강, Z 를 파랑으로 그림)

set tb [current_scope]
set d  $tb/dut

proc grp {name} { return [add_wave_group $name] }

# 1 클럭 · 리셋 (흰색). TB2 처럼 수 초짜리는 source 전에  set noclk 1  → clk 를 빼서 파형 파일을 작게
set g [grp "1 clk rst"]
if {[info exists noclk] && $noclk} {
    add_wave -into $g -color #FFFFFF $tb/rst
} else {
    add_wave -into $g -color #FFFFFF $tb/clk $tb/rst
}

# 2 버튼 · 스위치 (노랑)
set g [grp "2 button switch"]
add_wave -into $g -color #FFFF00 $tb/btn_R $tb/btn_L $tb/btn_U $tb/btn_D $tb/timer_sw4 $tb/mode_sw0

# 3 4 kHz 샘플 박자 (연두)
set g [grp "3 4kHz U_CLK_GEN_4KHZ"]
add_wave -into $g -color #9ACD32 $d/U_CLK_GEN_4KHZ/o_clk_4khz

# 4 디바운서 출력 (주황)
set g [grp "4 debounce o_btn"]
add_wave -into $g -color #FFA500 -name U_BD_R.o_btn $d/U_BD_R/o_btn
add_wave -into $g -color #FFA500 -name U_BD_L.o_btn $d/U_BD_L/o_btn
add_wave -into $g -color #FFA500 -name U_BD_U.o_btn $d/U_BD_U/o_btn
add_wave -into $g -color #FFA500 -name U_BD_D.o_btn $d/U_BD_D/o_btn

# 5 화면 선택 · 버튼 게이팅 (살구)
set g [grp "5 gating w_tm_btn"]
add_wave -into $g -color #FFDAB9 $d/w_sel_tm $d/w_tm_btn_R $d/w_tm_btn_L $d/w_tm_btn_U $d/w_tm_btn_D

# 6 타이머 FSM (분홍)
set g [grp "6 U_TIMER_CONTROL_UNIT"]
add_wave -into $g -color #FF69B4 $d/U_TIMER_CONTROL_UNIT/c_state $d/U_TIMER_CONTROL_UNIT/n_state
add_wave -into $g -color #FF69B4 $d/U_TIMER_CONTROL_UNIT/o_tm_add
add_wave -into $g -color #FF69B4 -radix unsigned $d/U_TIMER_CONTROL_UNIT/o_tm_amount
add_wave -into $g -color #FF69B4 $d/U_TIMER_CONTROL_UNIT/o_tm_run $d/U_TIMER_CONTROL_UNIT/o_tm_clear $d/U_TIMER_CONTROL_UNIT/o_tm_alarm

# 7 10 ms tick (연두)
set g [grp "7 10ms U_TICK_GEN_100HZ"]
add_wave -into $g -color #9ACD32 $d/U_TICK_GEN_100HZ/o_tick_10ms

# 8 타이머 값 (기본 초록, 10진수)
set g [grp "8 U_TIMER_DATAPATH"]
add_wave -into $g -color #00FF00 -radix unsigned $d/U_TIMER_DATAPATH/o_tm_min $d/U_TIMER_DATAPATH/o_tm_sec $d/U_TIMER_DATAPATH/o_tm_msec
add_wave -into $g -color #00FF00 $d/U_TIMER_DATAPATH/o_tm_zero

# 9 화면 MUX (하늘 대신 청록 — 파랑 계열 피함: 연보라)
set g [grp "9 display MUX"]
add_wave -into $g -color #DDA0DD -radix unsigned $d/w_disp_hour $d/w_disp_min $d/w_disp_msec
add_wave -into $g -color #DDA0DD $d/w_disp_mode

# 10 FND 출력 (흰색)
set g [grp "10 U_FND_CONTROLLER"]
add_wave -into $g -color #FFFFFF -radix bin $d/U_FND_CONTROLLER/o_fnd_com
add_wave -into $g -color #FFFFFF -radix hex $d/U_FND_CONTROLLER/o_fnd_font

# 11 LED (금색) — 알람 점멸 박자 확인용으로 시계 1/100초도 같이
set g [grp "11 LED"]
add_wave -into $g -color #FFD700 -radix hex $tb/led
add_wave -into $g -color #FFD700 -radix unsigned $d/U_WATCH_DATAPATH/o_wt_msec

puts "timer_wave_v2: 11 groups added under $tb. now: save wcfg, Relaunch Simulation, then run all"
