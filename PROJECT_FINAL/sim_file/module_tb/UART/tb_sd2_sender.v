`timescale 1ns / 1ps
// 단위 TB : uart_sender (+ sender_char_mux) — TX FIFO 자리에 "받아 적기" 만 하는 흉내
// (1) ~ (4) 형식 4 종 문자열 · busy 길이  (5) full 이면 기다렸다 이어서  (6) busy 중 send_go 무시
// (7) 보내는 도중 i_send_data 가 바뀌어도 처음 값  (8) 5 종 연달아 (auto all 흉내) 54 글자
// (9) send_go 전부터 full  (10) 마지막 글자 직전 full  (11) 마지막 글자 클럭의 send_go 무시  (12) 보내는 도중 rst
// (13) 랜덤 200 줄 (형식 · 값 · full 위치 무작위, 기대 글자는 make_exp 기대값 모델)
module tb_sd2_sender ();

    reg         clk, rst;
    reg         i_send_go;
    reg  [2:0]  i_send_sel;
    reg  [23:0] i_send_data;
    reg         i_tx_full;
    wire        o_send_busy, o_tx_push;
    wire [7:0]  o_tx_push_data;

    reg [7:0] got [0:63];        // TX FIFO 흉내 : push 된 글자를 순서대로 적어 둠
    integer cnt, busy_cnt, err, k;
    reg [8*11-1:0] tmp;
    reg [7:0] exp_c;
    // (13) 랜덤용
    reg rand_full;
    reg [7:0] ex [0:12];
    integer en, t, r;
    reg [2:0] rs;
    reg [23:0] rd;
    integer v1, v2, v3, v4;

    uart_sender dut (
        .clk           (clk),
        .rst           (rst),
        .i_send_go     (i_send_go),
        .i_send_sel    (i_send_sel),
        .i_send_data   (i_send_data),
        .i_tx_full     (i_tx_full),
        .o_send_busy   (o_send_busy),
        .o_tx_push     (o_tx_push),
        .o_tx_push_data(o_tx_push_data)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (o_tx_push) begin
            if (i_tx_full) begin
                err = err + 1;
                $display("%0t FAIL : push while full", $time);
            end
            got[cnt] = o_tx_push_data;
            cnt = cnt + 1;
        end
        if (o_send_busy) busy_cnt = busy_cnt + 1;
    end

    task clear_rec;
        begin
            cnt = 0;
            busy_cnt = 0;
        end
    endtask

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

    task wait_idle;
        begin
            @(posedge clk);
            wait (o_send_busy == 0);
            repeat (5) @(negedge clk);   // 끝난 뒤 더 나오는 글자가 없는지도 보려고 조금 더
        end
    endtask

    // got[off] 부터 body + CR LF 가 있는지
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
                if (got[off+k] !== exp_c) begin
                    err = err + 1;
                    $display("FAIL got[%0d] = %h expect %h", off + k, got[off+k], exp_c);
                end
            end
        end
    endtask

    task check_num(input integer value, input integer expect_v, input [8*16-1:0] what);
        begin
            if (value !== expect_v) begin
                err = err + 1;
                $display("FAIL %0s = %0d expect %0d", what, value, expect_v);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; err = 0; rand_full = 0;
        i_send_go = 0; i_send_sel = 0; i_send_data = 0; i_tx_full = 0;
        clear_rec;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);

        // (1) 스톱워치 12:34:56.78
        clear_rec;
        send(3'd0, {5'd12, 6'd34, 6'd56, 7'd78});
        wait_idle;
        check_at(0, "12:34:56.78", 11);
        check_num(cnt, 13, "push 수");
        check_num(busy_cnt, 13, "busy 클럭");
        $display("%0t (1) stopwatch 12:34:56.78 + CR LF : push %0d, busy %0d clk", $time, cnt, busy_cnt);

        // (2) 거리 400 cm
        clear_rec;
        send(3'd3, 24'd400);
        wait_idle;
        check_at(0, "400cm", 5);
        check_num(cnt, 7, "push 수");
        check_num(busy_cnt, 7, "busy 클럭");
        $display("%0t (2) distance 400cm + CR LF : push %0d, busy %0d clk", $time, cnt, busy_cnt);

        // (3) 온습도 45 % 25 C
        clear_rec;
        send(3'd4, {8'd0, 8'd45, 8'd25});
        wait_idle;
        check_at(0, "45%25C", 6);
        check_num(cnt, 8, "push 수");
        $display("%0t (3) hum/temp 45%%25C + CR LF : push %0d", $time, cnt);

        // (4) ERROR
        clear_rec;
        send(3'd7, 24'd0);
        wait_idle;
        check_at(0, "ERROR", 5);
        check_num(cnt, 7, "push 수");
        $display("%0t (4) ERROR + CR LF : push %0d", $time, cnt);

        // (5) 3 글자 넣은 뒤 TX FIFO full 20 클럭 → 기다렸다가 4 번째 글자부터 이어서
        clear_rec;
        send(3'd1, {5'd23, 6'd59, 6'd59, 7'd99});
        wait (cnt == 3);
        @(negedge clk);
        i_tx_full = 1;
        repeat (20) @(negedge clk);
        i_tx_full = 0;
        wait_idle;
        check_at(0, "23:59:59.99", 11);
        check_num(cnt, 13, "push 수");
        check_num(busy_cnt, 33, "busy 클럭");
        $display("%0t (5) full 20 clk : push %0d, busy %0d clk (13 + 20)", $time, cnt, busy_cnt);

        // (6) 보내는 중 (busy 1) 에 다른 send_go → 무시
        clear_rec;
        send(3'd0, {5'd1, 6'd2, 6'd3, 7'd4});
        send(3'd7, 24'd0);
        wait_idle;
        check_at(0, "01:02:03.04", 11);
        check_num(cnt, 13, "push 수");
        $display("%0t (6) send_go ignored while busy : push %0d (no ERROR mixed in)", $time, cnt);

        // (7) send_go 다음 클럭에 i_send_data 를 바꿔도 처음 값으로 보냄
        clear_rec;
        send(3'd2, {5'd10, 6'd20, 6'd30, 7'd40});
        i_send_data = 24'd0;
        wait_idle;
        check_at(0, "10:20:30.40", 11);
        $display("%0t (7) data changed while sending -> first value 10:20:30.40 kept", $time);

        // (8) 5 종 연달아 (busy 0 될 때마다 send_go) = 13 + 13 + 13 + 7 + 8 = 54 글자
        clear_rec;
        send(3'd0, {5'd12, 6'd34, 6'd56, 7'd78}); wait (o_send_busy == 0);
        send(3'd1, {5'd8, 6'd15, 6'd0, 7'd0});    wait (o_send_busy == 0);
        send(3'd2, {5'd0, 6'd5, 6'd0, 7'd0});     wait (o_send_busy == 0);
        send(3'd3, 24'd123);                      wait (o_send_busy == 0);
        send(3'd4, {8'd0, 8'd45, 8'd25});
        wait_idle;
        check_at(0, "12:34:56.78", 11);
        check_at(13, "08:15:00.00", 11);
        check_at(26, "00:05:00.00", 11);
        check_at(39, "123cm", 5);
        check_at(46, "45%25C", 6);
        check_num(cnt, 54, "push 수");
        $display("%0t (8) 5 formats back to back : push %0d, busy total %0d clk", $time, cnt, busy_cnt);

        // (9) send_go 전부터 TX FIFO full → 첫 글자부터 기다렸다가 풀리면 처음부터
        clear_rec;
        i_tx_full = 1;
        send(3'd0, {5'd7, 6'd8, 6'd9, 7'd10});
        repeat (5) @(negedge clk);
        i_tx_full = 0;
        wait_idle;
        check_at(0, "07:08:09.10", 11);
        check_num(cnt, 13, "push 수");
        check_num(busy_cnt, 18, "busy 클럭");
        $display("%0t (9) full from before send_go : push %0d, busy %0d clk (13 + 5)", $time, cnt, busy_cnt);

        // (10) 마지막 글자 (LF) 직전에 full 10 클럭 → LF 만 기다렸다가 넣고 끝
        clear_rec;
        send(3'd3, 24'd58);
        wait (cnt == 6);
        @(negedge clk);
        i_tx_full = 1;
        repeat (10) @(negedge clk);
        i_tx_full = 0;
        wait_idle;
        check_at(0, "058cm", 5);
        check_num(cnt, 7, "push 수");
        check_num(busy_cnt, 17, "busy 클럭");
        $display("%0t (10) full before last char LF : push %0d, busy %0d clk (7 + 10)", $time, cnt, busy_cnt);

        // (11) 마지막 글자를 넣는 클럭 (busy 아직 1) 에 온 send_go → 무시됨
        //      U_CONTROL 은 busy 가 0 인 걸 보고 send_go 를 줘야 한다는 확인 ((8) 은 busy 0 바로 다음 클럭 = 받음)
        clear_rec;
        send(3'd0, {5'd12, 6'd34, 6'd56, 7'd78});
        wait (cnt == 12);
        @(negedge clk);
        i_send_go = 1; i_send_sel = 3'd7; i_send_data = 24'd0;
        @(negedge clk);
        i_send_go = 0;
        wait_idle;
        check_at(0, "12:34:56.78", 11);
        check_num(cnt, 13, "push 수");
        $display("%0t (11) send_go on last-char clock (busy 1) ignored : push %0d", $time, cnt);

        // (12) 보내는 도중 rst → 바로 IDLE · busy 0, 남은 글자 안 나감, 그 뒤 새 send_go 는 정상
        clear_rec;
        send(3'd1, {5'd23, 6'd0, 6'd0, 7'd0});
        wait (cnt == 5);
        @(negedge clk);
        rst = 1;
        @(negedge clk);
        if (o_send_busy !== 1'b0) begin
            err = err + 1;
            $display("FAIL busy not 0 during rst");
        end
        rst = 0;
        repeat (20) @(negedge clk);
        check_num(cnt, 5, "push 수 (rst 뒤)");
        clear_rec;
        send(3'd3, 24'd7);
        wait_idle;
        check_at(0, "007cm", 5);
        check_num(cnt, 7, "push 수");
        $display("%0t (12) rst while sending : stopped at 5 chars, next send OK (007cm)", $time);

        // (13) 랜덤 200 줄 : 형식 · 값 무작위 + TX FIFO full 을 클럭마다 무작위 (약 1/4) — 기대 글자는 아래 make_exp 가 따로 계산
        rand_full = 1;
        for (t = 0; t < 200; t = t + 1) begin
            clear_rec;
            r = $random & 32'h7fff_ffff;
            case (r % 6)
                0, 1, 2: begin
                    rs = r % 3;
                    rd = {(($random & 32'h7fff_ffff) % 24) & 5'h1f, (($random & 32'h7fff_ffff) % 60) & 6'h3f,
                          (($random & 32'h7fff_ffff) % 60) & 6'h3f, (($random & 32'h7fff_ffff) % 100) & 7'h7f};
                end
                3: begin rs = 3; rd = ($random & 32'h7fff_ffff) % 401; end
                4: begin rs = 4; rd = {8'd0, ((($random & 32'h7fff_ffff) % 100) & 8'hff), ((($random & 32'h7fff_ffff) % 100) & 8'hff)}; end
                default: begin rs = 7; rd = $random; end
            endcase
            make_exp(rs, rd);
            send(rs, rd);
            wait_idle;
            if (cnt !== en) begin
                err = err + 1;
                $display("FAIL random #%0d sel %0d data %h : push %0d expect %0d", t, rs, rd, cnt, en);
            end
            for (k = 0; k < en; k = k + 1)
                if (got[k] !== ex[k]) begin
                    err = err + 1;
                    $display("FAIL random #%0d sel %0d data %h : got[%0d] = %h expect %h", t, rs, rd, k, got[k], ex[k]);
                end
        end
        rand_full = 0;
        @(negedge clk);
        i_tx_full = 0;
        $display("%0t (13) random 200 lines with random full : done", $time);

        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end

    // (13) 용 : 클럭마다 full 을 무작위로 (rand_full = 1 일 때만)
    always @(negedge clk)
        if (rand_full) i_tx_full = (($random & 3) == 0);

    // (13) 용 기대 글자 계산 (sender 와 따로 쓴 기대값 모델)
    task make_exp(input [2:0] sel, input [23:0] d);
        begin
            if (sel <= 2) begin
                v1 = d[23:19]; v2 = d[18:13]; v3 = d[12:7]; v4 = d[6:0];
                ex[0] = "0" + v1 / 10; ex[1] = "0" + v1 % 10; ex[2] = ":";
                ex[3] = "0" + v2 / 10; ex[4] = "0" + v2 % 10; ex[5] = ":";
                ex[6] = "0" + v3 / 10; ex[7] = "0" + v3 % 10; ex[8] = ".";
                ex[9] = "0" + v4 / 10; ex[10] = "0" + v4 % 10; ex[11] = 8'h0D; ex[12] = 8'h0A;
                en = 13;
            end else if (sel == 3) begin
                v1 = d[8:0];
                ex[0] = "0" + v1 / 100; ex[1] = "0" + (v1 / 10) % 10; ex[2] = "0" + v1 % 10;
                ex[3] = "c"; ex[4] = "m"; ex[5] = 8'h0D; ex[6] = 8'h0A;
                en = 7;
            end else if (sel == 4) begin
                v1 = d[15:8]; v2 = d[7:0];
                ex[0] = "0" + v1 / 10; ex[1] = "0" + v1 % 10; ex[2] = "%";
                ex[3] = "0" + v2 / 10; ex[4] = "0" + v2 % 10; ex[5] = "C";
                ex[6] = 8'h0D; ex[7] = 8'h0A;
                en = 8;
            end else begin
                ex[0] = "E"; ex[1] = "R"; ex[2] = "R"; ex[3] = "O"; ex[4] = "R";
                ex[5] = 8'h0D; ex[6] = 8'h0A;
                en = 7;
            end
        end
    endtask
endmodule
