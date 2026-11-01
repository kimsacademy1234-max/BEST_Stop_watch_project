# ISSUE 7 건 수정 (사본 C:/work/merge_fix4/src = v2 + J14 수정) — 원본 FINAL 은 그대로
#   py -3.10 -X utf8 apply_fix7.py
import re
S = r'C:/work/merge_fix4/src/'


def edit(path, pairs):
    p = S + path
    b = open(p, 'rb').read()
    try:
        enc = 'utf-8'; s = b.decode(enc)
    except UnicodeDecodeError:
        enc = 'cp949'; s = b.decode(enc)
    crlf = chr(13) + chr(10) in s
    s = s.replace(chr(13) + chr(10), chr(10))
    for a, rep, n in pairs:
        if isinstance(a, re.Pattern):
            s, k = a.subn(rep, s)
        else:
            k = s.count(a)
            s = s.replace(a, rep)
        assert k == n, (path, str(a)[:60], k)
    if crlf:
        s = s.replace(chr(10), chr(13) + chr(10))
    open(p, 'wb').write(s.encode(enc))
    print('edited', path)


# G3-3 : /set 은 옵션이 "w_hm" 일 때만 시계 설정을 켬 (/set abcd 로 켜지던 것)
edit('UART/01_UART_CONTROLLER.sv', [
    ("else if(i_set&&((c_module_control_bit & 7'b1110_111) == 7'b0000_010))",
     "else if(i_set && (i_con_ascii == \"w_hm\") && ((c_module_control_bit & 7'b1110_111) == 7'b0000_010))   // (fix 11/01 G3) 옵션 w_hm 일 때만", 1),
    # H9-1 : /get 요청을 1 비트 대신 개수 (5 비트) 로 기억 → FIFO 가 차서 기다리는 동안 온 /get 도 하나씩 응답
    ("reg c_send_pend, n_send_pend; // 아직 못 보낸 데이터 (5hz 차례 / get) 저장",
     "reg [4:0] c_send_pend, n_send_pend; // 아직 못 보낸 데이터 (5hz 차례 / get) 저장 — (fix 11/01 H9) get 은 개수로 셈", 1),
    ("                   n_send_pend = c_send_pend | (i_handshake && i_get);\n\n                   if(n_send_pend && !w_sender_busy && !n_err_pend)begin\n                        n_sender_go  = 1;\n                        n_send_pend  = 0;",
     "                   n_send_pend = c_send_pend + ((i_handshake && i_get && (c_send_pend != 5'd31)) ? 5'd1 : 5'd0);   // (fix 11/01 H9) 합치지 않고 개수 +1\n\n                   if((n_send_pend != 0) && !w_sender_busy && !n_err_pend)begin\n                        n_sender_go  = 1;\n                        n_send_pend  = n_send_pend - 5'd1;   // (fix 11/01 H9) 하나 보냈으면 하나만 뺌", 1),
    ("                    n_send_pend = c_send_pend | w_clk_5hz;",
     "                    n_send_pend = {4'd0, (c_send_pend != 0) | w_clk_5hz};   // (fix 11/01 H9) auto 는 전처럼 1 비트 표시", 1),
    # H7-2 : 자동 전송 1 초 카운터를 끌 때 0 으로 → 다시 켜면 첫 줄이 1 초 뒤
    (re.compile(r"(\t\t\telse begin *\n\t\t\t\to_clk <= 0;)"),
     r"\1\n\t\t\t\tr_counter <= 0;   // (fix 11/01 H7) 끌 때 카운터도 0", 1),
])

# G7-2 : /off 오타로 ERROR 가 난 뒤 off 카운터가 1 로 남던 것 → 오류 · 새 명령 시작 때 0
edit('UART/02_UART_ASCII_DECODER.sv', [
    ("       if(bad)begin\n            n_error = 1;",
     "       if(bad)begin\n            n_error = 1;\n            n_off = 0;   // (fix 11/01 G7) 오류 때 /off 글자 세던 값도 지움", 1),
])

# D7-2 : 랩을 띄워 둔 동안에도 UART 로는 지금 흐르는 값 (랩 전 카운터) 을 보냄
edit('WTS/stopwatch_datapath.v', [
    (re.compile(r"(    output \[HOUR_BIT_WIDTH-1:0\] o_sw_hour,)"),
     r"\1\n    output [23:0]               o_sw_run_time,   // (fix 11/01 D7) 랩과 상관없이 지금 흐르는 값 (UART 용)", 1),
    (re.compile(r"(    assign w_tick_10ms = i_tick_10ms;)"),
     r"\1\n    assign o_sw_run_time = {w_cnt_hour, w_cnt_min, w_cnt_sec, w_cnt_msec};   // (fix 11/01 D7)", 1),
    # L6-1 : 자리 올림 (o_tick) 을 레지스터 대신 조합으로 → 같은 클럭에 윗자리도 바뀜
    ("    output reg             o_tick\n", "    output                 o_tick   // (fix 11/01 L6) 조합 : 마지막 값에서 tick 오는 그 클럭에 바로\n", 1),
    ("    assign o_count = counter_reg;\n",
     "    assign o_count = counter_reg;\n    assign o_tick  = i_tick & ((i_down) ? (counter_reg == 0) : (counter_reg == TIMES - 1));   // (fix 11/01 L6)\n", 1),
    ("            o_tick <= 1'b0;\n        end else begin", "        end else begin", 1),
    ("                        o_tick <= 1'b1;\n", "", 2),
    ("                end else begin\n                    o_tick <= 1'b0;\n                end\n", "                end\n", 2),
])
edit('WTS/wts_top.v', [
    ("        .o_sw_lap   (o_sw_lap)\n    );", "        .o_sw_lap   (o_sw_lap),\n        .o_sw_run_time(w_sw_run_time)   // (fix 11/01 D7)\n    );", 1),
    ("    assign o_sw_time = {w_sw_hour, w_sw_min, w_sw_sec, w_sw_msec};",
     "    assign o_sw_time = w_sw_run_time;   // (fix 11/01 D7) 랩 표시 중에도 PC 로는 흐르는 값", 1),
    # E6-1 : 시계 설정은 시.분 화면 (sw1 = 1) 일 때만 → 초 화면에서 U 로 안 보이는 분이 바뀌던 것
    ("        .i_set_sw2  (i_set_sw2),", "        .i_set_sw2  (i_set_sw2 & i_display_mode_sw1),   // (fix 11/01 E6) 시.분 화면일 때만 설정", 1),
])
