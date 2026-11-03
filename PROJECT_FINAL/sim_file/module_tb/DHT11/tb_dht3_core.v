`timescale 1ns / 1ps
// dht11_core 통합 IP TB (요청 관리 · 자동 측정 · status)
// 시뮬레이션 시간 단축 : 1 tick = 100 ns (실제 1 us), 시작 LOW 180 tick,
//   부팅 대기 1000 클럭 (10 us), 측정 간격 100_000 클럭 (1 ms). 센서 모델도 같은 비율
//  (1) 부팅 대기 중 i_start → 기억했다가 대기 끝난 뒤 시작, 정상 값 · status 00
//  (2) done 뒤에도 간격 동안 o_busy = 1, o_measuring = 0
//  (3) 간격 안에 i_start → 기억, 앞 시작에서 1 ms 지난 뒤 시작
//  (4) i_auto_en = 1 → 1 ms 마다 자동 측정 3 번, 간격 1 ms 이상
//  (5) status : 응답 없음 01 · 중간에 끊김 10 · 체크섬 11, 값은 이전 정상값 유지
module tb_dht3_core ();
    localparam US       = 100;       // ns per tick (실제 1000)
    localparam BOOT     = 1000;      // 클럭
    localparam INTERVAL = 100_000;   // 클럭 = 1 ms

    reg clk, rst, start, auto_en, sensor_low;
    wire dht_io, w_oe;
    wire [7:0] hum, temp;
    wire [1:0] status;
    wire [3:0] state;
    wire valid, measuring, busy, done;
    integer err, n_start;
    time t_start, t_prev;

    pullup (dht_io);
    assign dht_io = sensor_low ? 1'b0 : 1'bz;
    assign dht_io = w_oe       ? 1'b0 : 1'bz;   // top 의 3상태 버퍼 역할

    dht11_core #(
        .BOOT_CYCLES    (BOOT),
        .INTERVAL_CYCLES(INTERVAL),
        .TICK_F_COUNT   (US / 10),
        .START_US       (180),
        .USE_ILA        (0)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .i_start      (start),
        .i_auto_en    (auto_en),
        .i_dht11      (dht_io),
        .o_dht_oe     (w_oe),
        .o_humidity   (hum),
        .o_temperature(temp),
        .o_valid      (valid),
        .o_status     (status),
        .o_measuring  (measuring),
        .o_busy       (busy),
        .o_done       (done),
        .o_state      (state)
    );

    always #5 clk = ~clk;

    // 측정 시작 시각 · 간격 검사
    always @(posedge dut.w_start) begin
        n_start = n_start + 1;
        t_prev  = t_start;
        t_start = $time;
        if (n_start > 1 && t_start - t_prev < INTERVAL * 10) begin
            err = err + 1; $display("%t MISMATCH start interval %0d ns (expect >= %0d)", $time, t_start - t_prev, INTERVAL * 10);
        end
    end

    function [39:0] frame;
        input [7:0] h, t;
        input bad;
        reg [7:0] s;
        begin
            s = h + t + (bad ? 8'd1 : 8'd0);
            frame = {h, 8'd0, t, 8'd0, s};
        end
    endfunction

    // nbits : 40 = 전체, 0 ~ 39 = 그만큼 보내고 선 놓음, -1 = 응답 없음
    task sensor_reply;
        input [39:0] f;
        input integer nbits;
        integer i;
        begin
            @(negedge dht_io);
            @(posedge dht_io);
            if (nbits >= 0) begin
                #(25 * US);
                sensor_low = 1; #(80 * US);
                sensor_low = 0; #(80 * US);
                for (i = 39; i >= 40 - nbits; i = i - 1) begin
                    sensor_low = 1; #(50 * US);
                    sensor_low = 0;
                    if (f[i]) #(70 * US); else #(27 * US);
                end
                if (nbits == 40) begin
                    sensor_low = 1; #(50 * US);
                    sensor_low = 0;
                end
            end
        end
    endtask

    task press_start;
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
        end
    endtask

    task check_result;
        input exp_valid;
        input [7:0] exp_h, exp_t;
        input [1:0] exp_st;
        begin
            @(negedge clk);
            if (valid !== exp_valid || hum !== exp_h || temp !== exp_t || status !== exp_st) begin
                err = err + 1;
                $display("%t MISMATCH valid %0d hum %0d temp %0d status %b (expect %0d / %0d / %0d / %b)",
                         $time, valid, hum, temp, status, exp_valid, exp_h, exp_t, exp_st);
            end else
                $display("%t valid %0d, %0d %%RH, %0d C, status %b", $time, valid, hum, temp, status);
        end
    endtask

    initial begin
        clk = 0; rst = 1; start = 0; auto_en = 0; sensor_low = 0;
        err = 0; n_start = 0; t_start = 0; t_prev = 0;
        #20 rst = 0;

        // (1) 부팅 대기 (10 us) 중에 요청
        #2000;
        fork
            sensor_reply(frame(40, 20, 0), 40);
            press_start;
        join
        if (t_start < BOOT * 10) begin
            err = err + 1; $display("%t (1) MISMATCH started at %0d ns, before boot wait", $time, t_start);
        end
        @(posedge done);
        check_result(1, 40, 20, 2'b00);

        // (2) done 뒤 간격 동안 busy
        #(100 * US);
        if (busy !== 1'b1 || measuring !== 1'b0) begin
            err = err + 1; $display("%t (2) MISMATCH busy %0d measuring %0d after done", $time, busy, measuring);
        end else
            $display("%t (2) after done: busy 1, measuring 0", $time);

        // (3) 간격 안 요청 → 1 ms 뒤 시작 (간격 검사는 always 블록)
        fork
            sensor_reply(frame(55, 24, 0), 40);
            press_start;
        join
        @(posedge done);
        check_result(1, 55, 24, 2'b00);

        // (4) 자동 측정 3 번
        n_start = 0;
        auto_en = 1;
        sensor_reply(frame(61, 25, 0), 40);
        @(posedge done); check_result(1, 61, 25, 2'b00);
        sensor_reply(frame(62, 26, 0), 40);
        @(posedge done); check_result(1, 62, 26, 2'b00);
        sensor_reply(frame(63, 27, 0), 40);
        @(posedge done); check_result(1, 63, 27, 2'b00);
        auto_en = 0;
        if (n_start !== 3) begin
            err = err + 1; $display("%t (4) MISMATCH auto starts %0d (expect 3)", $time, n_start);
        end else
            $display("%t (4) auto mode: 3 reads, 1 ms apart", $time);

        // (5) status 코드 (값은 63 / 27 유지)
        fork
            sensor_reply(0, -1);
            press_start;
        join
        @(posedge done); check_result(0, 63, 27, 2'b01);   // 응답 없음

        fork
            sensor_reply(frame(70, 30, 0), 10);
            press_start;
        join
        @(posedge done); check_result(0, 63, 27, 2'b10);   // 중간에 끊김

        fork
            sensor_reply(frame(70, 30, 1), 40);
            press_start;
        join
        @(posedge done); check_result(0, 63, 27, 2'b11);   // 체크섬

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end

    initial begin
        #100_000_000;
        $display("TOTAL MISMATCH = watchdog");
        $finish;
    end
endmodule
