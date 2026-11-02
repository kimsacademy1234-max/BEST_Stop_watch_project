`timescale 1ns / 1ps
// top_dht11 통합 TB. 시뮬레이션 시간 단축 : 1 tick = 100 ns (실제 1 us), 시작 LOW 180 tick,
// 디바운스 · 부팅 대기 · 측정 간격 (1 ms) · FND 스캔도 짧게. 센서 모델은 같은 비율 (US = 100 ns)
//  (1) 리셋 직후 "----"           (2) 짧은 버튼 튐 → 측정 안 함
//  (3) btnR → 55 %, 24 ℃ → FND "55.24" (자리별 font 확인), LED 정상
//  (4) 간격 (1 ms) 안에 누른 버튼 → 기억했다가 간격 뒤 측정, 체크섬 오류 → LED 오류 · "----"
//  (5) 응답 없음 → 오류          (6) 다시 정상 → "40.18"      (7) btnC 리셋 → "----"
module tb_dht2_top ();
    localparam US = 100;      // ns per tick (실제 1000)
    reg clk, rst, btnR, sensor_low;
    wire dht11_io;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [2:0] led;
    integer err, n_start;

    pullup (dht11_io);
    assign dht11_io = sensor_low ? 1'b0 : 1'bz;

    top_dht11 #(
        .BTN_F_COUNT    (4),          // 4 클럭마다 샘플 → 32 클럭 눌려야 인정
        .BOOT_CYCLES    (100),
        .INTERVAL_CYCLES(100_000),    // 1 ms
        .TICK_F_COUNT   (US / 10),
        .START_US       (180),
        .FND_SCAN       (1000),       // 자리당 10 us
        .USE_ILA        (0)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .btnR    (btnR),
        .dht11_io(dht11_io),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font),
        .led     (led)
    );

    always #5 clk = ~clk;
    always @(posedge dut.U_DHT11_CORE.w_start) n_start = n_start + 1;

    function [39:0] frame;
        input [7:0] h, t;
        input bad;
        reg [7:0] s;
        begin
            s = h + t + (bad ? 8'd1 : 8'd0);
            frame = {h, 8'd0, t, 8'd0, s};
        end
    endfunction

    // nbits : 40 = 전체, -1 = 응답 없음
    task sensor_reply;
        input [39:0] f;
        input integer nbits;
        integer i;
        begin
            @(negedge dht11_io);
            @(posedge dht11_io);
            if (nbits >= 0) begin
                #(25 * US);
                sensor_low = 1; #(80 * US);
                sensor_low = 0; #(80 * US);
                for (i = 39; i >= 0; i = i - 1) begin
                    sensor_low = 1; #(50 * US);
                    sensor_low = 0;
                    if (f[i]) #(70 * US); else #(27 * US);
                end
                sensor_low = 1; #(50 * US);
                sensor_low = 0;
            end
        end
    endtask

    task press;
        begin
            @(negedge clk); btnR = 1;
            repeat (100) @(negedge clk);
            btnR = 0;
        end
    endtask

    function [7:0] font_of;
        input integer n;
        begin
            case (n)
                0: font_of = 8'hc0; 1: font_of = 8'hf9; 2: font_of = 8'ha4; 3: font_of = 8'hb0;
                4: font_of = 8'h99; 5: font_of = 8'h92; 6: font_of = 8'h82; 7: font_of = 8'hf8;
                8: font_of = 8'h80; default: font_of = 8'h90;
            endcase
        end
    endfunction

    // 자리 0 = 온도 일의 자리 ... 자리 3 = 습도 십의 자리, 자리 2 뒤 소수점
    task check_display;
        input integer h, t;
        begin
            wait (fnd_com == 4'b1110); #1;
            if (fnd_font !== font_of(t % 10)) begin err = err + 1; $display("%t MISMATCH digit0 %h", $time, fnd_font); end
            wait (fnd_com == 4'b1101); #1;
            if (fnd_font !== font_of(t / 10)) begin err = err + 1; $display("%t MISMATCH digit1 %h", $time, fnd_font); end
            wait (fnd_com == 4'b1011); #1;
            if (fnd_font !== (font_of(h % 10) & 8'h7f)) begin err = err + 1; $display("%t MISMATCH digit2+dot %h", $time, fnd_font); end
            wait (fnd_com == 4'b0111); #1;
            if (fnd_font !== font_of(h / 10)) begin err = err + 1; $display("%t MISMATCH digit3 %h", $time, fnd_font); end
            $display("%t FND = %0d%0d.%0d%0d", $time, h / 10, h % 10, t / 10, t % 10);
        end
    endtask

    initial begin
        clk = 0; rst = 1; btnR = 0; sensor_low = 0; err = 0; n_start = 0;
        #100 rst = 0;
        #2000;

        // (1)
        if (fnd_font !== 8'hbf || led[2:0] !== 3'b000) begin err = err + 1; $display("%t (1) MISMATCH after reset font %h led %b", $time, fnd_font, led); end
        else $display("%t (1) after reset: ----", $time);

        // (2)
        @(negedge clk); btnR = 1;
        repeat (3) @(negedge clk); btnR = 0;
        #5000;
        if (n_start !== 0) begin err = err + 1; $display("%t (2) MISMATCH button bounce started a read", $time); end
        else $display("%t (2) short button bounce ignored", $time);

        // (3)
        fork
            press;
            sensor_reply(frame(55, 24, 0), 40);
        join
        @(posedge dut.w_done); repeat (4) @(negedge clk);
        if (led[2:0] !== 3'b100) begin err = err + 1; $display("%t (3) MISMATCH led %b", $time, led); end
        check_display(55, 24);

        // (4) 1 ms 간격 안에 누름 → 간격 뒤 측정, 체크섬 오류
        fork
            press;
            sensor_reply(frame(60, 20, 1), 40);
        join
        @(posedge dut.w_done); repeat (4) @(negedge clk);
        if (led[2:0] !== 3'b010 || fnd_font !== 8'hbf) begin err = err + 1; $display("%t (4) MISMATCH led %b font %h", $time, led, fnd_font); end
        else $display("%t (4) checksum error -> LED1, ----", $time);

        // (5) 응답 없음
        fork
            press;
            sensor_reply(0, -1);
        join
        @(posedge dut.w_done); repeat (4) @(negedge clk);
        if (led[2:0] !== 3'b010) begin err = err + 1; $display("%t (5) MISMATCH led %b", $time, led); end
        else $display("%t (5) no response -> error", $time);

        // (6) 복구
        fork
            press;
            sensor_reply(frame(40, 18, 0), 40);
        join
        @(posedge dut.w_done); repeat (4) @(negedge clk);
        if (led[2:0] !== 3'b100) begin err = err + 1; $display("%t (6) MISMATCH led %b", $time, led); end
        check_display(40, 18);

        if (n_start !== 4) begin err = err + 1; $display("%t MISMATCH %0d reads (expect 4)", $time, n_start); end

        // (7)
        @(negedge clk); rst = 1;
        repeat (5) @(negedge clk); rst = 0;
        repeat (5) @(negedge clk);
        if (fnd_font !== 8'hbf || led !== 3'b000) begin err = err + 1; $display("%t (7) MISMATCH after btnC reset font %h led %b", $time, fnd_font, led); end
        else $display("%t (7) btnC reset -> ----", $time);

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end

    initial begin
        #100_000_000;
        $display("TOTAL MISMATCH = watchdog");
        $finish;
    end
endmodule
