`timescale 1ns / 1ps

// =============================================================================
//  tb_merge_final_top : full-system test of merge_final_top (board pins only)
//
//  - drive buttons / switches / UART commands, check FND / LED / UART replies
//    on the console and in the waveform
//  - sensor models : SR04 (echo), DHT11 (response + 40 bits),
//                    value and error case can be changed from the scenario
//  - PC receiver   : prints each line sent by the FPGA, PC_TEXT (ASCII) in waveform
//  - FND decoder   : FND_AN / FND_NUM = anode lit now and the character on it (ASCII),
//                    FND_TEXT = the whole 4-digit display (ASCII)
//
//  Write the test in the "SCENARIO" block at the bottom.
//
//  Tasks
//    uart_send("/mod dist");   send one command line (CR is added)
//    press("R");               press a board button (R L U D, C = reset button)
//    hold("U", 300);           hold a board button for 300 ms
//    wait_ms(100);             wait
//    show();                   print FND text, LEDs, screen, UART control state
//    dist_err(1);              SR04 model : 0 normal, 1 no echo, 2 out of range, 3 echo stuck
//    dht_err(1);               DHT11 model: 0 normal, 1 no response, 2 timeout, 3 checksum error
//
//  Check tasks (one log line each : send time, result time, delay, PASS / FAIL)
//    cmd_pc ("/get ",     "55%24C", 50);   send a command, expect this UART line within 50 ms
//    cmd_fnd("/mod dist", "000.0", 20);    send a command, expect this FND text within 20 ms
//    btn_fnd("R",         "100.0", 100);   press a button, expect this FND text within 100 ms
//    report();                             print the summary table (call at the end)
//  delay = result time - end of sending (negative : the result came while the command was still being sent)
//  Sensor values : sr04_cm = 123;  dht_hum = 55;  dht_temp = 24;
//  Switches      : sw0 ~ sw6, sw15  (e.g. sw5 = 1;)
// =============================================================================

// Shorter simulation (comment out to use the real board timing)
//   DHT11 boot wait 1 s -> 1 ms, measure interval 2 s -> 50 ms
//   /auto send period 1 Hz -> 50 Hz
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

    // ------------------------------------------------------------------ text for the waveform (Radix : ASCII)
    reg [8*16-1:0] CMD_TEXT = 0;   // command being sent
    reg [8*16-1:0] PC_TEXT  = 0;   // last line received from the FPGA
    reg [8*8-1:0]  FND_TEXT = 0;   // what the FND shows now
    // last check (cmd_pc / cmd_fnd / btn_fnd), same as the console log
    integer        CHK_NUM       = 0;   // check number
    reg [8*16-1:0] CHK_CMD       = 0;   // command / button          (ASCII)
    reg [8*16-1:0] CHK_EXPECT    = 0;   // expected UART line / FND  (ASCII)
    reg [8*16-1:0] CHK_GOT       = 0;   // what was seen             (ASCII)
    reg [8*4-1:0]  CHK_RESULT    = 0;   // "WAIT" / "PASS" / "FAIL"  (ASCII)
    integer        CHK_SENT_US   = 0;   // end of sending            (us)
    integer        CHK_RESULT_US = 0;   // time the result was seen  (us)
    integer        CHK_DELAY_US  = 0;   // result - end of sending   (us)

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
    defparam dut.U_DHT11.BOOT_CYCLES     = 100_000;     // 1 ms
    defparam dut.U_DHT11.INTERVAL_CYCLES = 5_000_000;   // 50 ms
    defparam dut.U_UART.AUTO_FRQ         = 50;          // 50 Hz
`endif

    always #5 clk = ~clk;   // 100 MHz

    // =================================================================== tasks
    task automatic wait_ms(input integer ms);
        repeat (ms) #1_000_000;
    endtask

    // button : the debouncer needs 8 samples at 4 kHz (2 ms) -> hold, then release 5 ms
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
    string    pc_line = "";
    reg       pc_new  = 1;   // next char starts a new line
    string    pc_last = "";  // last complete line
    event     pc_line_ev;    // a line has been received
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
                pc_last = pc_line;
                -> pc_line_ev;
                pc_line = "";
                pc_new  = 1;
            end else if (pc_ch != 8'h0D) begin
                if (pc_new) begin PC_TEXT = 0; pc_new = 0; end   // keep the last line until the next one
                pc_line = $sformatf("%s%c", pc_line, pc_ch);
                PC_TEXT = {PC_TEXT[8*15-1:0], pc_ch};
            end
        end
    end

    // =================================================================== SR04 model
    // 0.5 ms after trig falls, echo = 1 for sr04_cm x 58 us
    integer sr04_cm   = 100;
    integer sr04_mode = 0;   // 0 normal, 1 no echo, 2 out of range (30 ms), 3 echo stuck

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
            echo = 1;   // stays 1
        end
    end

    // =================================================================== DHT11 model
    // when the FPGA holds the line LOW for more than 1 ms and releases it :
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
    event     fnd_ev;        // FND text updated (every 2 ms)

    function automatic [7:0] seg2ch(input [7:0] f);
        case (f)
            8'hC0: seg2ch = "0";  8'hF9: seg2ch = "1";  8'hA4: seg2ch = "2";  8'hB0: seg2ch = "3";
            8'h99: seg2ch = "4";  8'h92: seg2ch = "5";  8'h82: seg2ch = "6";  8'hF8: seg2ch = "7";
            8'h80: seg2ch = "8";  8'h90: seg2ch = "9";  8'h86: seg2ch = "E";  8'hAF: seg2ch = "r";
            8'hBF: seg2ch = "-";  8'hFF: seg2ch = " ";  default: seg2ch = "?";
        endcase
    endfunction

    // ---- live output, like verification_v2 fnd_monitor (fnd_an / fnd_num)
    //   FND_AN  : fnd_com -> "AN0" ~ "AN3" (all off 1111 = "---", more than one on = "ERR")
    //   FND_NUM : fnd_font (7-seg hex, active-low) -> the character a person sees on that anode
    //             '0'~'9', 'E', 'r', '-', ' ' (blank), '.' (dot only)
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
        else            font2ascii = seg2ch({1'b1, f[6:0]});   // digit with or without the dot bit
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

    // print the current state
    task automatic show();
        string scr;
        case (dut.U_FND_CONTROLLER.i_disp_sel)
            2'd1:    scr = "DIST";
            2'd2:    scr = "TEMP";
            default: scr = "WTS";
        endcase
        $display("[%9.3f ms] FND \"%s\"  LED %b  screen %s  (UART control %b, ctrl_bit %b)",
                 $realtime / 1e6, fnd_str(), led, scr,
                 dut.U_UART.o_uart_mode, dut.U_UART.o_module_control_bit);
    endtask

    // =================================================================== check (PASS / FAIL log)
    string   log_q[$];          // one line per check, printed again by report()
    integer  n_chk = 0, n_pass = 0, n_fail = 0;
    bit      chk_ok;            // result seen
    string   chk_got;           // last value seen
    realtime chk_t;             // time the result was seen

    // fixed-width text for the log columns
    function automatic string pad(input string str, input integer w);
        string r;
        r = str;
        while (r.len() < w) r = {r, " "};
        return r;
    endfunction

    // string -> 16 char ASCII register (for the waveform)
    function automatic [8*16-1:0] s2r(input string str);
        integer i;
        s2r = 0;
        for (i = 0; i < str.len() && i < 16; i = i + 1) s2r = {s2r[8*15-1:0], str[i]};
    endfunction

    // act      : command text or button name
    // is_btn   : 1 = press a button, 0 = send a UART command
    // want_pc  : 1 = wait for a UART line, 0 = wait for an FND text
    task automatic do_check(input string act, input bit is_btn, input bit want_pc,
                            input string exp, input integer timeout_ms);
        realtime t0, t1;
        string   line, what;
        chk_ok  = 0;
        chk_got = want_pc ? "(no line)" : fnd_str();
        chk_t   = 0;
        n_chk   = n_chk + 1;
        t0      = $realtime;
        CHK_NUM       = n_chk;
        CHK_CMD       = s2r(act);
        CHK_EXPECT    = s2r(exp);
        CHK_GOT       = 0;
        CHK_RESULT    = "WAIT";
        CHK_SENT_US   = 0;
        CHK_RESULT_US = 0;
        CHK_DELAY_US  = 0;

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
                    if (chk_got == exp) begin
                        chk_ok = 1;
                        chk_t  = $realtime;
                        disable WATCH;
                    end
                end
            end
        join_none

        if (is_btn) press(act);
        else        uart_send(act);
        t1 = $realtime;
        CHK_SENT_US = t1 / 1e3;

        fork
            wait (chk_ok);
            #(timeout_ms * 1_000_000.0);
        join_any
        disable fork;

        what = want_pc ? "UART" : "FND ";
        CHK_GOT    = s2r(chk_got);
        CHK_RESULT = chk_ok ? "PASS" : "FAIL";
        if (chk_ok) begin
            CHK_RESULT_US = chk_t / 1e3;
            CHK_DELAY_US  = (chk_t - t1) / 1e3;
        end
        if (chk_ok) begin
            n_pass = n_pass + 1;
            line = $sformatf("#%02d PASS | %s %s | sent %9.3f ~ %9.3f ms | expect %s %s | got %s at %9.3f ms (delay %8.3f ms)",
                             n_chk, is_btn ? "BTN" : "CMD", pad(act, 12), t0 / 1e6, t1 / 1e6, what,
                             pad({"\"", exp, "\""}, 10), pad({"\"", chk_got, "\""}, 10), chk_t / 1e6, (chk_t - t1) / 1e6);
        end else begin
            n_fail = n_fail + 1;
            line = $sformatf("#%02d FAIL | %s %s | sent %9.3f ~ %9.3f ms | expect %s %s | got %s (timeout %0d ms)",
                             n_chk, is_btn ? "BTN" : "CMD", pad(act, 12), t0 / 1e6, t1 / 1e6, what,
                             pad({"\"", exp, "\""}, 10), pad({"\"", chk_got, "\""}, 10), timeout_ms);
        end
        log_q.push_back(line);
        $display("[%9.3f ms] %s", $realtime / 1e6, line);
    endtask

    task automatic cmd_pc(input string cmd, input string exp, input integer timeout_ms);
        do_check(cmd, 0, 1, exp, timeout_ms);
    endtask

    task automatic cmd_fnd(input string cmd, input string exp, input integer timeout_ms);
        do_check(cmd, 0, 0, exp, timeout_ms);
    endtask

    task automatic btn_fnd(input string b, input string exp, input integer timeout_ms);
        do_check(b, 1, 0, exp, timeout_ms);
    endtask

    // summary : time sent, command, expected, result time, delay, PASS / FAIL
    task automatic report();
        integer i;
        $display("");
        $display("==================================================================== RESULT");
        for (i = 0; i < log_q.size(); i = i + 1) $display("%s", log_q[i]);
        $display("--------------------------------------------------------------------");
        $display("checks %0d : PASS %0d, FAIL %0d", n_chk, n_pass, n_fail);
        $display("====================================================================");
    endtask

    // =================================================================== SCENARIO
    initial begin
        rst = 1;
        #1000;
        rst = 0;
        wait_ms(5);
        $display("========== scenario start ==========");

        // ---------------- write the scenario here ----------------
        // e.g.
        // cmd_fnd("/mod dist", "000.0", 20);         // distance screen, no measurement yet
        // btn_fnd("R", "100.0", 100);                // one measurement (sr04_cm = 100)
        // sr04_cm = 35;
        // btn_fnd("U", "035.0", 200);                // auto measure on
        // dist_err(1);
        // btn_fnd("R", "Err1", 200);                 // no echo
        // dist_err(0);
        // cmd_fnd("/mod temp", "----", 20);          // humidity / temperature, before the first result
        // btn_fnd("R", "55.24", 100);                // one measurement (55 %, 24 C)
        // cmd_pc ("/get ", "55%24C", 50);            // UART reply
        // cmd_pc ("/gxt ", "ERROR", 50);             // wrong command
        // cmd_pc ("/auto dis", "035cm", 100);        // auto send
        // uart_send("/auto off");
        // cmd_fnd("/mod w_hm", "12.00", 600);        // watch hh.mm (12 h display after reset), dot blinks every 0.5 s
        // ---------------------------------------------------------

        show();
        report();
        wait_ms(10);
        $display("========== scenario end ==========");
        $finish;
    end

endmodule
