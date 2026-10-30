`timescale 1ns / 1ps
// dht11_controller 단위 TB (TB 가 DHT11 센서 역할, 실제 타이밍)
// 시뮬레이션 시간 단축 : 1 tick = 100 ns (실제 1 us), 시작 LOW 180 tick (실제 18000).
//  센서 모델도 같은 비율 (US = 100 ns) 이라 비트 판단 비율 27 : 70 (기준 40) 은 실제와 같음
//  (1) 시작 LOW START tick 이상 (+1 tick 미만)   (2) 센서가 응답할 때 FPGA 는 선을 놓고 있음
//  (3) 정상 프레임 → o_valid 1, 습도 · 온도 일치, done 1 클럭
//  (4) 응답 시작 20 / 25 / 40 us (WAIT 30 us 보다 늦게 내려가는 경우 포함)
//  (5) 소수 바이트가 있어도 체크섬 계산 맞음   (6) 체크섬 틀림 → valid 0, 이전 값 유지
//  (7) 응답 없음 → timeout → valid 0           (8) 10 비트 보내고 멈춤 → timeout → valid 0
//  (9) 오류 뒤 정상 복구                       (10) 측정 중 start 무시
//  매 측정 : o_status = 00 OK / 01 응답 없음 / 10 중간에 끊김 / 11 체크섬
module tb_dht1_ctrl ();
    localparam US    = 100;   // ns per tick (실제 1000)
    localparam START = 180;   // 시작 LOW tick (실제 18000)
    reg clk, rst, start, sensor_low;
    wire w_tick, w_tick_en, w_tick_clr, valid, done, busy;
    wire [7:0] hum, temp;
    wire [1:0] status;
    wire [3:0] state;
    wire dht_io, w_oe;
    integer err, n_done, n_start_low;
    time t_low;

    // 오픈 드레인 버스 : 풀업 + 센서 LOW + FPGA LOW
    pullup (dht_io);
    assign dht_io = sensor_low ? 1'b0 : 1'bz;
    assign dht_io = w_oe       ? 1'b0 : 1'bz;   // top 의 3상태 버퍼 역할

    tick_gen_1us #(.F_COUNT(US / 10)) U_TICK (
        .clk     (clk),
        .rst     (rst),
        .i_enable(w_tick_en),
        .i_clear (w_tick_clr),
        .o_tick  (w_tick)
    );

    dht11_controller #(.START_US(START), .USE_ILA(0)) dut (
        .clk          (clk),
        .rst          (rst),
        .i_start      (start),
        .i_us_tick    (w_tick),
        .i_dht11      (dht_io),
        .o_dht_oe     (w_oe),
        .o_humidity   (hum),
        .o_temperature(temp),
        .o_valid      (valid),
        .o_status     (status),
        .o_state      (state),
        .o_done       (done),
        .o_busy       (busy),
        .o_tick_en    (w_tick_en),
        .o_tick_clr   (w_tick_clr)
    );

    always #5 clk = ~clk;
    always @(posedge clk) if (done === 1'b1) n_done = n_done + 1;
    always @(posedge dut.c_oe) n_start_low = n_start_low + 1;

    function [39:0] frame;
        input [7:0] h, hd, t, td;
        input bad;
        reg [7:0] s;
        begin
            s = h + hd + t + td + (bad ? 8'd1 : 8'd0);
            frame = {h, hd, t, td, s};
        end
    endfunction

    // 센서 흉내. nbits : 40 = 전체, 0 ~ 39 = 그만큼 보내고 선 놓음, -1 = 응답 없음
    task sensor_reply;
        input [39:0] f;
        input integer resp_us;
        input integer nbits;
        integer i;
        begin
            @(negedge dht_io); t_low = $time;
            @(posedge dht_io);
            if ($time - t_low < START * US || $time - t_low >= (START + 1) * US) begin
                err = err + 1; $display("%t (1) MISMATCH start LOW %0d ns", $time, $time - t_low);
            end
            if (nbits >= 0) begin
                #(resp_us * US);
                if (dut.c_oe !== 1'b0) begin
                    err = err + 1; $display("%t (2) MISMATCH FPGA still drives the line when the sensor answers", $time);
                end
                sensor_low = 1; #(80 * US);       // 응답 LOW
                sensor_low = 0; #(80 * US);       // 응답 HIGH
                for (i = 39; i >= 40 - nbits; i = i - 1) begin
                    sensor_low = 1; #(50 * US);   // 비트 앞 LOW
                    sensor_low = 0;
                    if (f[i]) #(70 * US); else #(27 * US);
                end
                if (nbits == 40) begin
                    sensor_low = 1; #(50 * US);   // 끝 LOW
                    sensor_low = 0;               // 선 놓음
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

    task read;
        input [39:0] f;
        input integer resp_us;
        input integer nbits;
        input exp_valid;
        input [7:0] exp_h, exp_t;
        input [1:0] exp_st;
        begin
            n_done = 0;
            fork
                sensor_reply(f, resp_us, nbits);
                begin press_start; @(posedge done); end
            join
            @(negedge clk); @(negedge clk);
            if (valid !== exp_valid || hum !== exp_h || temp !== exp_t) begin
                err = err + 1;
                $display("%t MISMATCH valid %0d hum %0d temp %0d (expect %0d / %0d / %0d)",
                         $time, valid, hum, temp, exp_valid, exp_h, exp_t);
            end else
                $display("%t frame %h, reply %0d us, %0d bits -> valid %0d, %0d %%RH, %0d C",
                         $time, f, resp_us, nbits, valid, hum, temp);
            if (status !== exp_st) begin
                err = err + 1; $display("%t MISMATCH status %b (expect %b)", $time, status, exp_st);
            end
            if (n_done !== 1) begin err = err + 1; $display("%t (3) MISMATCH done for %0d clocks", $time, n_done); end
            if (busy !== 1'b0 || dut.c_oe !== 1'b0) begin
                err = err + 1; $display("%t MISMATCH not IDLE / line not released after read", $time);
            end
            #(100 * US);
        end
    endtask

    initial begin
        clk = 0; rst = 1; start = 0; sensor_low = 0;
        err = 0; n_done = 0; n_start_low = 0;
        #20 rst = 0;
        #3000;

        read(frame(55, 0, 24, 0, 0), 25, 40, 1, 55, 24, 2'b00);   // (3)
        read(frame(45, 7, 31, 5, 0), 40, 40, 1, 45, 31, 2'b00);   // (4) 40 us, (5) 소수 바이트
        read(frame(0, 0, 0, 0, 0),   30, 40, 1,  0,  0, 2'b00);
        read(frame(91, 0, 37, 0, 0), 20, 40, 1, 91, 37, 2'b00);   // (4) 20 us
        read(frame(60, 0, 20, 0, 1), 30, 40, 0, 91, 37, 2'b11);   // (6) 체크섬 틀림 → 이전 값 유지
        read(frame(60, 0, 20, 0, 0), 30, -1, 0, 91, 37, 2'b01);   // (7) 응답 없음
        read(frame(60, 0, 20, 0, 0), 30, 10, 0, 91, 37, 2'b10);   // (8) 중간에 멈춤
        read(frame(50, 0, 25, 0, 0), 30, 40, 1, 50, 25, 2'b00);   // (9) 복구

        // (10) 측정 중 start 다시 → 무시 (시작 LOW 1 번)
        n_start_low = 0;
        fork
            sensor_reply(frame(33, 0, 22, 0, 0), 30, 40);
            begin
                press_start;
                #(START / 2 * US);    press_start;   // START 중
                #((START + 1000) * US); press_start; // 데이터 받는 중
                @(posedge done);
            end
        join
        #(100 * US);
        if (n_start_low !== 1 || hum !== 33 || temp !== 22) begin
            err = err + 1; $display("%t (10) MISMATCH start during read: %0d start pulses, %0d / %0d", $time, n_start_low, hum, temp);
        end else
            $display("%t (10) start during read ignored (%0d start pulse)", $time, n_start_low);

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end

    initial begin
        #100_000_000;
        $display("TOTAL MISMATCH = watchdog");
        $finish;
    end
endmodule
