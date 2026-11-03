`timescale 1ns / 1ps
// 단위 TB : sender_char_mux (조합) — 형식마다 idx 0 ~ 끝 글자를 기대 문자열과 비교
// 기대 : 모든 줄 끝 CR (0D) LF (0A), o_last_idx = 글자 수 - 1
module tb_sd1_char ();

    reg  [2:0]  i_sel;
    reg  [23:0] i_data;
    reg  [3:0]  i_idx;
    wire [7:0]  o_char;
    wire [3:0]  o_last_idx;

    integer err, k;
    reg [8*11-1:0] tmp;
    reg [7:0] exp_c;

    sender_char_mux dut (
        .i_sel     (i_sel),
        .i_data    (i_data),
        .i_idx     (i_idx),
        .o_char    (o_char),
        .o_last_idx(o_last_idx)
    );

    // body = CR LF 앞 글자들 (n 개), 끝에 CR LF 가 붙는지까지 확인
    task check_line(input [2:0] sel, input [23:0] data, input [8*11-1:0] body, input integer n);
        begin
            i_sel  = sel;
            i_data = data;
            for (k = 0; k < n + 2; k = k + 1) begin
                i_idx = k;
                #1;
                if (k < n) begin
                    tmp   = body >> (8 * (n - 1 - k));
                    exp_c = tmp[7:0];
                end else if (k == n) begin
                    exp_c = 8'h0D;
                end else begin
                    exp_c = 8'h0A;
                end
                if (o_char !== exp_c) begin
                    err = err + 1;
                    $display("FAIL sel %0d idx %0d : got %h expect %h", sel, k, o_char, exp_c);
                end
            end
            if (o_last_idx !== n + 1) begin
                err = err + 1;
                $display("FAIL sel %0d : o_last_idx %0d expect %0d", sel, o_last_idx, n + 1);
            end
            $display("%0t sel %0d : \"%0s\" + CR LF (%0d chars) OK", $time, sel, body, n + 2);
        end
    endtask

    initial begin
        err = 0;
        i_idx = 0;
        // 시간 3 종 : {hour 5, min 6, sec 6, cs 7}
        check_line(3'd0, {5'd12, 6'd34, 6'd56, 7'd78}, "12:34:56.78", 11);
        check_line(3'd1, {5'd0, 6'd0, 6'd0, 7'd0}, "00:00:00.00", 11);
        check_line(3'd2, {5'd23, 6'd59, 6'd59, 7'd99}, "23:59:59.99", 11);
        check_line(3'd0, {5'd9, 6'd5, 6'd7, 7'd3}, "09:05:07.03", 11);
        // 거리 : cm 9 비트, 3 자리 (앞자리 0)
        check_line(3'd3, 24'd0, "000cm", 5);
        check_line(3'd3, 24'd7, "007cm", 5);
        check_line(3'd3, 24'd58, "058cm", 5);
        check_line(3'd3, 24'd400, "400cm", 5);
        // 온습도 : {8'b0, hum 8, temp 8}
        check_line(3'd4, {8'd0, 8'd45, 8'd25}, "45%25C", 6);
        check_line(3'd4, {8'd0, 8'd0, 8'd0}, "00%00C", 6);
        check_line(3'd4, {8'd0, 8'd99, 8'd50}, "99%50C", 6);
        // ERROR : 7 (5 · 6 도 ERROR 로 처리 — 정할 것), 데이터는 무시
        check_line(3'd7, 24'hABCDEF, "ERROR", 5);
        check_line(3'd5, 24'h123456, "ERROR", 5);
        check_line(3'd6, 24'h000000, "ERROR", 5);
        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
