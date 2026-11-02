`timescale 1ns / 1ps

// =============================================================================
//  tb_merge_final_top : full-system scenario test of merge_final_top (v2)
//
//  Design sources : FINAL/source_file/merge_final_v2/ (all .v / .sv, sub folders included)
//  Sim sources    : this file only  -> Set as Top, open tb_merge_final_top_behav.wcfg
//  Guide          : tb_merge_final_top.md (scenario list, what to look at, wave groups)
//
//  - board pins only are driven (buttons, switches, rx, sensor pins)
//  - sensor models : SR04 (echo), DHT11 (response + 40 bits)
//  - PC receiver   : prints every line sent by the FPGA
//  - FND decoder   : FND_TEXT = what a person reads on the 4 digits
//  - every check   : one log line (scenario, time sent, time seen, delay, PASS / FAIL)
//  - SCN_NUM / SCN_NAME at the top of the waveform = scenario running now
// =============================================================================

// Shorter simulation (tb only, the RTL is not changed). Comment out for board timing.
//   watch / stopwatch / timer : 100x  (1 s  -> 10 ms,  10 ms tick -> 100 us)
//   /auto send               : 1 Hz -> 50 Hz
//   DHT11                    : boot 1 s -> 1 ms, interval 2 s -> 50 ms, start LOW 18 ms -> 2 ms
//   SR04                     : period 60 ms -> 10 ms, no-echo wait 30 ms -> 5 ms,
//                              wait after echo 10 ms -> 2 ms, stuck 50 ms -> 10 ms
`define FAST_SIM

module tb_merge_final_top;

    // ------------------------------------------------------------------ board pins
    reg  clk = 0;
    reg  rst = 0;
    reg  btn_R = 0, btn_L = 0, btn_U = 0, btn_D = 0;
    reg  sw0 = 0, sw1 = 0, sw2 = 0, sw3 = 0, sw4 = 0, sw5 = 0, sw6 = 0, sw15 = 1;
    reg  rx = 1;
    wire tx;
    wire trig;
    reg  echo = 0;
    wire dht11_io;
    wire [ 3:0] fnd_com;
    wire [ 7:0] fnd_font;
    wire [15:0] led;

    // ------------------------------------------------------------------ waveform text (Radix : ASCII)
    integer        SCN_NUM       = 0;   // scenario number (S01 ...)
    reg [8*28-1:0] SCN_NAME      = 0;   // scenario name
    reg [8*16-1:0] CMD_TEXT      = 0;   // command being sent
    reg [8*16-1:0] PC_TEXT       = 0;   // last line received from the FPGA
    reg [8*8-1:0]  FND_TEXT      = 0;   // what the FND shows now
    integer        CHK_NUM       = 0;   // check number
    reg [8*28-1:0] CHK_CMD       = 0;   // command / button of the check
    reg [8*28-1:0] CHK_EXPECT    = 0;   // expected value
    reg [8*28-1:0] CHK_GOT       = 0;   // value seen
    reg [8*4-1:0]  CHK_RESULT    = 0;   // "WAIT" / "PASS" / "FAIL"
    integer        CHK_DELAY_US  = 0;   // result time - end of sending (us)

    // ------------------------------------------------------------------ DUT
    merge_final_top dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (sw0),
        .display_mode_sw1(sw1),
        .set_sw2         (sw2),
        .hour24_sw3      (sw3),
        .timer_sw4       (sw4),
        .dist_sw5        (sw5),
        .dht_sw6         (sw6),
        .dist_led_sw15   (sw15),
        .rx              (rx),
        .tx              (tx),
        .trig            (trig),
        .echo            (echo),
        .dht11_io        (dht11_io),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

`ifdef FAST_SIM
    defparam dut.U_WTS.U_TICK_GEN_100HZ.F_COUNT = 10_000;      // 100 us = 1/100 s
    defparam dut.U_WTS.U_TICK_GEN_SW.F_COUNT    = 10_000;
    defparam dut.U_WTS.U_TICK_GEN_TM.F_COUNT    = 10_000;
    defparam dut.U_UART.AUTO_FRQ                = 50;          // 20 ms
    defparam dut.U_DHT11.BOOT_CYCLES            = 100_000;     // 1 ms
    defparam dut.U_DHT11.INTERVAL_CYCLES        = 5_000_000;   // 50 ms
    defparam dut.U_DHT11.START_US               = 2_000;       // 2 ms
    defparam dut.U_SR04.U_SR04.U_SR04_CNTL.MEAS_PERIOD_US  = 10_000;
    defparam dut.U_SR04.U_SR04.U_SR04_CNTL.WAIT_TIMEOUT_US = 5_000;
    defparam dut.U_SR04.U_SR04.U_SR04_CNTL.STOP_US         = 2_000;
    defparam dut.U_SR04.U_SR04.U_SR04_CNTL.STUCK_US        = 10_000;
`endif

    always #5 clk = ~clk;   // 100 MHz

    // =================================================================== basic tasks
    task automatic wait_ms(input integer ms);
        repeat (ms) #1_000_000;
    endtask

    // board button : the debouncer needs 8 samples at 4 kHz (2 ms) -> hold, then release 5 ms
    task automatic hold(input string b, input integer ms);
        if      (b == "R") btn_R = 1;
        else if (b == "L") btn_L = 1;
        else if (b == "U") btn_U = 1;
        else if (b == "D") btn_D = 1;
        else if (b == "C") rst   = 1;
        else $display("[tb] hold : unknown button %s", b);
        $display("[%9.3f ms] BTN  %s (%0d ms)", $realtime / 1e6, b, ms);
        wait_ms(ms);
        btn_R = 0; btn_L = 0; btn_U = 0; btn_D = 0; rst = 0;
        wait_ms(5);
    endtask

    task automatic press(input string b);
        hold(b, 5);
    endtask

    // UART 9600 8N1 : PC -> FPGA
    localparam real BIT_NS = 1_000_000_000.0 / 9600.0;

    task automatic uart_byte(input [7:0] c);
        integer i;
        rx = 0; #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin
            rx = c[i]; #(BIT_NS);
        end
        rx = 1; #(BIT_NS);
    endtask

    task automatic uart_send(input string s);
        integer i;
        $display("[%9.3f ms] PC -> \"%s\"", $realtime / 1e6, s);
        CMD_TEXT = 0;
        for (i = 0; i < s.len(); i = i + 1) begin
            CMD_TEXT = {CMD_TEXT[8*15-1:0], s[i]};
            uart_byte(s[i]);
        end
        uart_byte(8'h0D);   // CR : needed by /get and /set 24h, ignored by the others
        #(BIT_NS * 10);
    endtask

    // =================================================================== PC receiver (FPGA -> PC)
    reg [7:0] pc_ch;
    string    pc_line  = "";
    string    pc_last  = "";   // last complete line
    reg       pc_new   = 1;
    integer   pc_count = 0;    // number of lines received
    event     pc_line_ev;
    integer   k;
    initial begin
        forever begin
            @(negedge tx);
            #(BIT_NS * 1.5);
            for (k = 0; k < 8; k = k + 1) begin
                pc_ch[k] = tx;
                #(BIT_NS);
            end
            if (pc_ch == 8'h0A) begin
                $display("[%9.3f ms] PC <- \"%s\"", $realtime / 1e6, pc_line);
                pc_last  = pc_line;
                pc_count = pc_count + 1;
                -> pc_line_ev;
                pc_line = "";
                pc_new  = 1;
            end else if (pc_ch != 8'h0D) begin
                if (pc_new) begin PC_TEXT = 0; pc_new = 0; end
                pc_line = $sformatf("%s%c", pc_line, pc_ch);
                PC_TEXT = {PC_TEXT[8*15-1:0], pc_ch};
            end
        end
    end

    // =================================================================== SR04 model
    // 0.5 ms after trig falls, echo = 1 for sr04_cm x 58 us
    integer sr04_cm   = 100;
    integer sr04_mode = 0;   // 0 normal, 1 no echo, 2 out of range (echo 30 ms), 3 echo stuck at 1

    task automatic dist_err(input integer m);
        sr04_mode = m;
        if (m != 3) echo = 0;
        $display("[%9.3f ms] SR04 model : %s", $realtime / 1e6,
                 m == 0 ? "normal" : m == 1 ? "no echo (Err1)" : m == 2 ? "out of range (Err2)" : "echo stuck (Err3)");
    endtask

    always @(negedge trig) begin
        if (sr04_mode == 0 || sr04_mode == 2) begin
            #500_000;
            echo = 1;
            if (sr04_mode == 0) #(sr04_cm * 58_000);
            else                #30_000_000;
            echo = 0;
        end else if (sr04_mode == 3) begin
            #500_000;
            echo = 1;
        end
    end

    // =================================================================== DHT11 model
    // FPGA holds the line LOW (> 1 ms) and releases it ->
    //   LOW 80 us, HIGH 80 us, 40 bits (LOW 50 us + HIGH 26 us = 0 / 70 us = 1), LOW 50 us
    integer dht_hum  = 55;
    integer dht_temp = 24;
    integer dht_mode = 0;    // 0 normal, 1 no response, 2 timeout (stops after 20 bits), 3 checksum error
    reg     dht_drv  = 0;

    assign dht11_io = dht_drv ? 1'b0 : 1'bz;
    pullup (dht11_io);

    task automatic dht_err(input integer m);
        dht_mode = m;
        $display("[%9.3f ms] DHT11 model : %s", $realtime / 1e6,
                 m == 0 ? "normal" : m == 1 ? "no response (Err1)" : m == 2 ? "timeout (Err2)" : "checksum error (Err3)");
    endtask

    reg  [39:0] dht_bits;
    reg  [ 7:0] dht_sum;
    realtime    t_low;
    integer     n, nbit;
    initial begin
        forever begin
            @(negedge dht11_io);
            t_low = $realtime;
            @(posedge dht11_io);
            if ($realtime - t_low > 1_000_000 && dht_mode != 1) begin
                dht_sum  = dht_hum[7:0] + dht_temp[7:0] + ((dht_mode == 3) ? 8'd1 : 8'd0);
                dht_bits = {dht_hum[7:0], 8'd0, dht_temp[7:0], 8'd0, dht_sum};
                nbit     = (dht_mode == 2) ? 20 : 40;
                #30_000;
                dht_drv = 1; #80_000;
                dht_drv = 0; #80_000;
                for (n = 39; n >= 40 - nbit; n = n - 1) begin
                    dht_drv = 1; #50_000;
                    dht_drv = 0;
                    if (dht_bits[n]) #70_000; else #26_000;
                end
                if (dht_mode != 2) begin
                    dht_drv = 1; #50_000;
                    dht_drv = 0;
                end
            end
        end
    end

    // =================================================================== FND decoder
    // scan slot 0~3 = digit AN0~AN3, slot 4~7 = dot of the same digit (fnd_font = 7F)
    reg [7:0] fnd_ch  [0:3];
    reg       fnd_dot [0:3];
    reg [2:0] scan;
    integer   d;
    event     fnd_ev;        // FND_TEXT updated (every 2 ms)

    function automatic [7:0] seg2ch(input [7:0] f);
        case (f)
            8'hC0: seg2ch = "0";  8'hF9: seg2ch = "1";  8'hA4: seg2ch = "2";  8'hB0: seg2ch = "3";
            8'h99: seg2ch = "4";  8'h92: seg2ch = "5";  8'h82: seg2ch = "6";  8'hF8: seg2ch = "7";
            8'h80: seg2ch = "8";  8'h90: seg2ch = "9";  8'h86: seg2ch = "E";  8'hAF: seg2ch = "r";
            8'hBF: seg2ch = "-";  8'hFF: seg2ch = " ";  default: seg2ch = "?";
        endcase
    endfunction

    // live output, like verification_v2 fnd_monitor (fnd_an / fnd_num)
    //   FND_AN  : fnd_com  -> "AN0" ~ "AN3" (all off = "---", more than one on = "ERR")
    //   FND_NUM : fnd_font -> the character on that anode ('0'~'9', 'E', 'r', '-', ' ', '.')
    function automatic [23:0] an_name(input [3:0] c);
        case (c)
            4'b1110: an_name = "AN0";
            4'b1101: an_name = "AN1";
            4'b1011: an_name = "AN2";
            4'b0111: an_name = "AN3";
            4'b1111: an_name = "---";
            default: an_name = "ERR";
        endcase
    endfunction

    function automatic [7:0] font2ascii(input [7:0] f);
        if (f == 8'h7F) font2ascii = ".";
        else            font2ascii = seg2ch({1'b1, f[6:0]});
    endfunction

    wire [23:0] FND_AN  = an_name(fnd_com);
    wire [7:0]  FND_NUM = font2ascii(fnd_font);

    initial begin
        for (d = 0; d < 4; d = d + 1) begin
            fnd_ch[d]  = " ";
            fnd_dot[d] = 0;
        end
    end

    always @(dut.U_FND_CONTROLLER.U_COUNTER8.o_scan_sel) begin
        #1;
        scan = dut.U_FND_CONTROLLER.U_COUNTER8.o_scan_sel;
        if (scan[2] == 1'b0) fnd_ch[scan[1:0]]  = seg2ch(fnd_font);
        else                 fnd_dot[scan[1:0]] = (fnd_font == 8'h7F);
        if (scan == 3'd7) begin
            FND_TEXT = 0;
            for (d = 3; d >= 0; d = d - 1) begin
                FND_TEXT = {FND_TEXT[8*7-1:0], fnd_ch[d]};
                if (fnd_dot[d]) FND_TEXT = {FND_TEXT[8*7-1:0], 8'h2E};
            end
            -> fnd_ev;
        end
    end

    function automatic string fnd_str();
        integer i;
        string  r;
        r = "";
        for (i = 7; i >= 0; i = i - 1)
            if (FND_TEXT[i*8 +: 8] != 0) r = $sformatf("%s%c", r, FND_TEXT[i*8 +: 8]);
        return r;
    endfunction

    function automatic string scr_name();
        case (dut.U_FND_CONTROLLER.i_disp_sel)
            2'd1:    return "DIST";
            2'd2:    return "TEMP";
            default: return "WTS";
        endcase
    endfunction

    task automatic show();
        $display("[%9.3f ms] FND \"%s\"  LED %b  screen %s  (UART control %b, ctrl_bit %b)",
                 $realtime / 1e6, fnd_str(), led, scr_name(),
                 dut.U_UART.o_uart_mode, dut.U_UART.o_module_control_bit);
    endtask

    // =================================================================== scenario marker
    string cur_scn = "S00";

    // string -> ASCII register for the waveform
    function automatic [8*28-1:0] s2r(input string str);
        integer i;
        s2r = 0;
        for (i = 0; i < str.len() && i < 28; i = i + 1) s2r = {s2r[8*27-1:0], str[i]};
    endfunction

    task automatic scenario(input integer num, input string name);
        SCN_NUM  = num;
        SCN_NAME = s2r(name);
        cur_scn  = $sformatf("S%02d", num);
        $display("");
        $display("[%9.3f ms] ======== %s %s ========", $realtime / 1e6, cur_scn, name);
    endtask

    // =================================================================== checks
    //   expected text : '?' = any one character
    //                   if the expected text has no '.', dots on the FND are ignored
    //                   (the watch / timer centre dot blinks)
    string   log_q[$];
    integer  n_chk = 0, n_pass = 0, n_fail = 0;
    bit      chk_ok;
    string   chk_got;
    realtime chk_t;

    function automatic string pad(input string str, input integer w);
        string r;
        r = str;
        while (r.len() < w) r = {r, " "};
        return r;
    endfunction

    function automatic bit match(input string got, input string exp);
        string g;
        integer i;
        bit has_dot;
        has_dot = 0;
        for (i = 0; i < exp.len(); i = i + 1) if (exp[i] == ".") has_dot = 1;
        g = "";
        for (i = 0; i < got.len(); i = i + 1)
            if (has_dot || got[i] != ".") g = $sformatf("%s%c", g, got[i]);
        if (g.len() != exp.len()) return 0;
        for (i = 0; i < exp.len(); i = i + 1)
            if (exp[i] != "?" && exp[i] != g[i]) return 0;
        return 1;
    endfunction

    task automatic log_result(input string act, input string what, input string exp,
                              input string got, input bit ok, input realtime t1, input realtime t2,
                              input integer timeout_ms);
        string line;
        n_chk = n_chk + 1;
        if (ok) n_pass = n_pass + 1; else n_fail = n_fail + 1;
        CHK_NUM    = n_chk;
        CHK_GOT    = s2r(got);
        CHK_RESULT = ok ? "PASS" : "FAIL";
        if (ok) CHK_DELAY_US = (t2 - t1) / 1e3;
        if (ok)
            line = $sformatf("%s #%02d PASS | %s | sent %9.3f ms | expect %s %s | got %s at %9.3f ms (delay %8.3f ms)",
                             cur_scn, n_chk, pad(act, 14), t1 / 1e6, what, pad({"\"", exp, "\""}, 13),
                             pad({"\"", got, "\""}, 13), t2 / 1e6, (t2 - t1) / 1e6);
        else
            line = $sformatf("%s #%02d FAIL | %s | sent %9.3f ms | expect %s %s | got %s (timeout %0d ms)",
                             cur_scn, n_chk, pad(act, 14), t1 / 1e6, what, pad({"\"", exp, "\""}, 13),
                             pad({"\"", got, "\""}, 13), timeout_ms);
        log_q.push_back(line);
        $display("[%9.3f ms] %s", $realtime / 1e6, line);
    endtask

    // act_type : 0 = send UART command, 1 = press board button, 2 = nothing (just wait for the result)
    // want_pc  : 1 = wait for a UART line, 0 = wait for an FND text
    task automatic do_check(input string act, input integer act_type, input bit want_pc,
                            input string exp, input integer timeout_ms);
        realtime t1;
        string   label;
        chk_ok  = 0;
        chk_got = want_pc ? "(no line)" : fnd_str();
        chk_t   = 0;
        label   = (act_type == 0) ? {"CMD ", act} : (act_type == 1) ? {"BTN ", act} : "WAIT";
        CHK_CMD    = s2r(label);
        CHK_EXPECT = s2r(exp);
        CHK_GOT    = 0;
        CHK_RESULT = "WAIT";
        CHK_DELAY_US = 0;

        // start watching before sending : a reply may finish while the command is still being sent
        fork
            begin : WATCH
                forever begin
                    if (want_pc) begin
                        @(pc_line_ev);
                        chk_got = pc_last;
                    end else begin
                        @(fnd_ev);
                        chk_got = fnd_str();
                    end
                    if (match(chk_got, exp)) begin
                        chk_ok = 1;
                        chk_t  = $realtime;
                        disable WATCH;
                    end
                end
            end
        join_none

        if (act_type == 0)      uart_send(act);
        else if (act_type == 1) press(act);
        t1 = $realtime;

        fork
            wait (chk_ok);
            #(timeout_ms * 1_000_000.0);
        join_any
        disable fork;

        log_result(label, want_pc ? "UART" : "FND ", exp, chk_got, chk_ok, t1, chk_t, timeout_ms);
    endtask

    task automatic cmd_pc  (input string cmd, input string exp, input integer timeout_ms); do_check(cmd, 0, 1, exp, timeout_ms); endtask
    task automatic cmd_fnd (input string cmd, input string exp, input integer timeout_ms); do_check(cmd, 0, 0, exp, timeout_ms); endtask
    task automatic btn_fnd (input string b,   input string exp, input integer timeout_ms); do_check(b,   1, 0, exp, timeout_ms); endtask
    task automatic wait_fnd(                  input string exp, input integer timeout_ms); do_check("",  2, 0, exp, timeout_ms); endtask
    task automatic wait_pc (                  input string exp, input integer timeout_ms); do_check("",  2, 1, exp, timeout_ms); endtask

    // check a value right now
    task automatic check_now(input string name, input string got, input string exp);
        CHK_CMD    = s2r(name);
        CHK_EXPECT = s2r(exp);
        log_result(name, "NOW ", exp, got, match(got, exp), $realtime, $realtime, 0);
    endtask

    function automatic string b2s(input bit v);
        return v ? "1" : "0";
    endfunction

    task automatic report();
        integer i;
        $display("");
        $display("============================================================================ RESULT");
        for (i = 0; i < log_q.size(); i = i + 1) $display("%s", log_q[i]);
        $display("------------------------------------------------------------------------------------");
        $display("checks %0d : PASS %0d, FAIL %0d", n_chk, n_pass, n_fail);
        $display("====================================================================================");
    endtask

    // =================================================================== SCENARIO
    //   numbers and names match tb_merge_final_top.md
    string  line1;
    integer cnt0;

    initial begin
        // ---------------------------------------------------------------- S01
        scenario(1, "reset");
        rst = 1; #1000; rst = 0;
        wait_ms(5);
        check_now("uart control", b2s(dut.U_UART.o_uart_mode), "0");
        check_now("screen",       scr_name(),                    "WTS");
        check_now("led (watch)",  $sformatf("%04h", led),        "8009");   // watch 12:00 = PM -> led[15]
        check_now("tx idle",      b2s(tx),                       "1");

        // ---------------------------------------------------------------- S02
        scenario(2, "switch : watch hh.mm 12h/24h");
        // the watch starts at 12:00 -> "12.00" in both 12 h and 24 h, the PM LED (led[15]) tells them apart
        sw1 = 1;
        wait_fnd("1200", 20);
        check_now("PM led 12h", b2s(led[15]), "1");
        sw3 = 1;
        wait_ms(5);
        check_now("PM led 24h", b2s(led[15]), "0");
        sw3 = 0; sw1 = 0;

        // ---------------------------------------------------------------- S03
        scenario(3, "switch : distance screen");
        sw5 = 1;
        wait_fnd("000.0", 20);                      // no measurement yet
        check_now("screen", scr_name(), "DIST");

        // ---------------------------------------------------------------- S04
        scenario(4, "switch : distance btn R");
        sr04_cm = 100;
        btn_fnd("R", "100.0", 60);

        // ---------------------------------------------------------------- S05
        scenario(5, "switch : temp screen + btn R");
        sw6 = 1;
        wait_fnd("----", 20);                       // no result yet
        btn_fnd("R", "55.24", 60);

        // ---------------------------------------------------------------- S06
        scenario(6, "UART /mod dist (switch off)");
        cmd_fnd("/mod dist", "100.0", 20);           // last distance kept
        check_now("uart control", b2s(dut.U_UART.o_uart_mode), "1");
        sw5 = 0; sw6 = 0;                           // switches are ignored now
        wait_ms(5);
        check_now("screen", scr_name(), "DIST");

        // ---------------------------------------------------------------- S07
        scenario(7, "UART /btn R (35 cm)");
        sr04_cm = 35;
        cmd_fnd("/btn R", "035.0", 60);

        // ---------------------------------------------------------------- S08
        scenario(8, "UART /btn U auto on (250 cm)");
        sr04_cm = 250;
        cmd_fnd("/btn U", "250.0", 80);
        check_now("sr04 auto", b2s(dut.U_SR04.o_auto_en), "1");

        // ---------------------------------------------------------------- S09
        scenario(9, "SR04 error Err1 Err2 Err3");
        dist_err(1);  wait_fnd("Err1", 60);
        dist_err(2);  wait_fnd("Err2", 80);
        dist_err(3);  wait_fnd("Err3", 150);
        dist_err(0);  wait_fnd("250.0", 100);

        // ---------------------------------------------------------------- S10
        scenario(10, "UART /get distance");
        cmd_pc("/get ", "250cm", 50);
        dist_err(1);  wait_fnd("Err1", 60);
        cmd_pc("/get ", "Err 1", 50);               // v2 : error is sent as "Err N"
        dist_err(0);  wait_fnd("250.0", 100);

        // ---------------------------------------------------------------- S11
        scenario(11, "UART /btn U auto off");
        uart_send("/btn U");
        wait_ms(5);
        check_now("sr04 auto", b2s(dut.U_SR04.o_auto_en), "0");

        // ---------------------------------------------------------------- S12
        scenario(12, "UART /mod temp + /get");
        cmd_fnd("/mod temp", "55.24", 20);
        cmd_pc("/get ", "55%24C", 50);

        // ---------------------------------------------------------------- S13
        scenario(13, "DHT11 error + new value");
        dht_err(1);
        cmd_fnd("/btn R", "Err1", 150);
        cmd_pc("/get ", "Err 1", 50);
        dht_err(3);
        cmd_fnd("/btn R", "Err3", 150);
        dht_err(0); dht_hum = 60; dht_temp = 25;
        cmd_fnd("/btn R", "60.25", 150);
        cmd_pc("/get ", "60%25C", 50);

        // ---------------------------------------------------------------- S14
        scenario(14, "DHT11 auto on / off (LED3)");
        uart_send("/btn U");  wait_ms(5);
        check_now("led[3] auto", b2s(led[3]), "1");
        uart_send("/btn U");  wait_ms(5);
        check_now("led[3] auto", b2s(led[3]), "0");

        // ---------------------------------------------------------------- S15
        scenario(15, "UART /auto dis / tem / all / off");
        cmd_pc("/auto dis", "250cm", 60);           // last distance (SR04 auto is off since S11)
        cmd_pc("/auto tem", "60%25C", 60);
        uart_send("/auto all");
        wait_pc("??:??:??.??", 120);                // a time line (stopwatch / timer / watch)
        wait_pc("60%25C", 120);
        uart_send("/auto off");
        wait_ms(40);                                // last line may still be on the wire
        cnt0 = pc_count;
        wait_ms(60);
        check_now("no line after off", $sformatf("%0d", pc_count - cnt0), "0");

        // ---------------------------------------------------------------- S16
        scenario(16, "wrong command -> ERROR");
        cmd_pc("/gxt ", "ERROR", 50);

        // ---------------------------------------------------------------- S17
        scenario(17, "UART watch /set 24h 12h");
        cmd_fnd("/mod w_hm", "12??", 20);           // 12:mm
        check_now("PM led 12h", b2s(led[15]), "1");
        uart_send("/set 24h");  wait_ms(5);
        check_now("PM led 24h", b2s(led[15]), "0");
        uart_send("/set 12h");  wait_ms(5);
        check_now("PM led 12h", b2s(led[15]), "1");

        // ---------------------------------------------------------------- S18
        scenario(18, "UART stopwatch run/stop/clear");
        uart_send("/mod s_ms");
        uart_send("/btn R");                        // run
        wait_ms(20);
        uart_send("/btn R");                        // stop
        cmd_pc("/get ", "00:00:0?.??", 50);
        line1 = pc_last;
        wait_ms(10);
        cmd_pc("/get ", line1, 50);                 // stopped : same value
        uart_send("/btn L");                        // clear
        cmd_pc("/get ", "00:00:00.00", 50);

        // ---------------------------------------------------------------- S19
        scenario(19, "UART timer 10 s + alarm");
        uart_send("/mod t_ms");
        uart_send("/btn U");                        // +10 s
        cmd_pc("/get ", "00:00:10.00", 50);
        uart_send("/btn L");                        // start
        wait_ms(120);                               // 10 s = 100 ms (FAST_SIM)
        check_now("timer alarm", b2s(dut.U_WTS.o_tm_alarm), "1");
        uart_send("/btn L");                        // any button = alarm off
        wait_ms(5);
        check_now("timer alarm", b2s(dut.U_WTS.o_tm_alarm), "0");

        // ---------------------------------------------------------------- S20
        scenario(20, "reset during /auto all");
        uart_send("/auto all");
        wait_ms(30);
        press("C");                                 // board reset button
        cnt0 = pc_count;
        wait_ms(60);
        check_now("uart control", b2s(dut.U_UART.o_uart_mode), "0");
        check_now("screen",       scr_name(),                    "WTS");
        check_now("no line after reset", $sformatf("%0d", pc_count - cnt0), "0");

        scenario(99, "end");
        show();
        report();
        $finish;
    end

endmodule
