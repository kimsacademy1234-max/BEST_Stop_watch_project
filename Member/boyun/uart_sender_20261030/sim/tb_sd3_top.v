`timescale 1ns / 1ps
// Top TB : sender_tx_top (sender → TX FIFO 64 칸 → uart_tx) — PC 쪽에서 tx 선을 받아 문자열 비교
// 같이 추가할 파일 : uart_sender.v · sender_char_mux.v · fifo.v · uart_tx.v · (baud_tick_gen 이 든) uart.v · uart_rx.v
// (1) 스톱워치 한 줄 : PC 가 받은 13 글자 · busy 13 클럭 · 다 나가는 시간
// (2) 5 종 연달아 54 글자 : busy 합 54 클럭 (TX FIFO 가 안 차서 기다림 없음) · PC 가 받은 54 글자
module tb_sd3_top ();

    parameter BIT = 104_160;      // 1 비트 = b_tick 16 번 = 651 클럭 × 16 × 10 ns (9600 bps 에 가까운 값)

    reg         clk, rst;
    reg         i_send_go;
    reg  [2:0]  i_send_sel;
    reg  [23:0] i_send_data;
    wire        o_send_busy, tx;

    reg [7:0] rx [0:127];        // PC 가 받은 글자
    reg [7:0] rdata;
    integer rcnt, busy_cnt, err, k, b;
    reg [8*11-1:0] tmp;
    reg [7:0] exp_c;
    time t_go, t_end;

    sender_tx_top dut (
        .clk        (clk),
        .rst        (rst),
        .i_send_go  (i_send_go),
        .i_send_sel (i_send_sel),
        .i_send_data(i_send_data),
        .o_send_busy(o_send_busy),
        .tx         (tx)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (o_send_busy) busy_cnt = busy_cnt + 1;
    end

    // PC 흉내 : start 비트 하강 → 반 비트 뒤부터 비트 가운데에서 8 번 읽기 (LSB 먼저) → stop
    always begin
        @(negedge tx);
        #(BIT / 2);
        if (tx !== 1'b0) begin
            err = err + 1;
            $display("%0t FAIL : start bit is not 0", $time);
        end
        for (b = 0; b < 8; b = b + 1) begin
            #(BIT);
            rdata[b] = tx;
        end
        #(BIT);
        if (tx !== 1'b1) begin
            err = err + 1;
            $display("%0t FAIL : stop bit is not 1", $time);
        end
        rx[rcnt] = rdata;
        rcnt = rcnt + 1;
        t_end = $time;
    end

    task send(input [2:0] sel, input [23:0] data);
        begin
            @(negedge clk);
            i_send_go   = 1;
            i_send_sel  = sel;
            i_send_data = data;
            @(negedge clk);
            i_send_go = 0;
        end
    endtask

    task check_at(input integer off, input [8*11-1:0] body, input integer n);
        begin
            for (k = 0; k < n + 2; k = k + 1) begin
                if (k < n) begin
                    tmp   = body >> (8 * (n - 1 - k));
                    exp_c = tmp[7:0];
                end else if (k == n) begin
                    exp_c = 8'h0D;
                end else begin
                    exp_c = 8'h0A;
                end
                if (rx[off+k] !== exp_c) begin
                    err = err + 1;
                    $display("FAIL PC rx[%0d] = %h expect %h", off + k, rx[off+k], exp_c);
                end
            end
        end
    endtask

    initial begin
        #200_000_000;
        $display("TIMEOUT : PC received %0d chars", rcnt);
        $display("TOTAL MISMATCH = %0d", err + 1);
        $stop;
    end

    initial begin
        clk = 0; rst = 1; err = 0; rcnt = 0; busy_cnt = 0;
        i_send_go = 0; i_send_sel = 0; i_send_data = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);

        // (1) 스톱워치 한 줄
        busy_cnt = 0;
        t_go = $time;
        send(3'd0, {5'd12, 6'd34, 6'd56, 7'd78});
        wait (rcnt == 13);
        check_at(0, "12:34:56.78", 11);
        if (busy_cnt !== 13) begin
            err = err + 1;
            $display("FAIL busy %0d clk expect 13 (waited for full TX FIFO?)", busy_cnt);
        end
        $display("%0t (1) PC got 13 chars, busy %0d clk, send_go -> last stop bit %0d ns", $time, busy_cnt, t_end - t_go);

        // (2) 5 종 연달아 (busy 0 될 때마다 send_go)
        busy_cnt = 0;
        t_go = $time;
        send(3'd0, {5'd12, 6'd34, 6'd56, 7'd78}); wait (o_send_busy == 0);
        send(3'd1, {5'd8, 6'd15, 6'd0, 7'd0});    wait (o_send_busy == 0);
        send(3'd2, {5'd0, 6'd5, 6'd0, 7'd0});     wait (o_send_busy == 0);
        send(3'd3, 24'd123);                      wait (o_send_busy == 0);
        send(3'd4, {8'd0, 8'd45, 8'd25});
        wait (rcnt == 13 + 54);
        check_at(13, "12:34:56.78", 11);
        check_at(26, "08:15:00.00", 11);
        check_at(39, "00:05:00.00", 11);
        check_at(52, "123cm", 5);
        check_at(59, "45%25C", 6);
        if (busy_cnt !== 54) begin
            err = err + 1;
            $display("FAIL busy total %0d clk expect 54 (waited for full TX FIFO?)", busy_cnt);
        end
        $display("%0t (2) 5 formats: PC got 54 chars, busy total %0d clk, all sent in %0d ns", $time, busy_cnt, t_end - t_go);

        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
