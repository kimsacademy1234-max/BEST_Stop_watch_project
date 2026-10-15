`timescale 1ns / 1ps

// watch_tick_counter 단위 검사: tick 우선, 칸만 돌기(올림·내림 없음), (10/16) +-10
module tb_watch_tick_counter ();
    reg clk, rst, i_tick, i_up, i_down, i_step10;
    wire [5:0] time_count;
    wire o_tick;
    integer err;

    watch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(6),
        .INIT(5)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_tick(i_tick),
        .i_up(i_up),
        .i_down(i_down),
        .i_step10(i_step10),
        .time_count(time_count),
        .o_tick(o_tick)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; err = 0; i_tick = 0; i_up = 0; i_down = 0; i_step10 = 0;
        #22 rst = 0;
        if (time_count !== 6'd5) begin err = err + 1; $display("INIT FAIL %0d", time_count); end

        // tick 과 up 이 같은 클럭 -> tick 만 반영 (5 -> 6)
        @(negedge clk); i_tick = 1; i_up = 1;
        @(negedge clk); i_tick = 0; i_up = 0;
        if (time_count !== 6'd6) begin err = err + 1; $display("PRIORITY FAIL %0d", time_count); end

        // tick 과 down 이 같은 클럭 -> tick 만 반영 (6 -> 7). 버튼이 이기면 5 가 됨
        @(negedge clk); i_tick = 1; i_down = 1;
        @(negedge clk); i_tick = 0; i_down = 0;
        if (time_count !== 6'd7) begin err = err + 1; $display("PRIORITY(down) FAIL %0d", time_count); end

        // up 단독 7 -> 8, down 단독 8 -> 7
        @(negedge clk); i_up = 1;
        @(negedge clk); i_up = 0;
        if (time_count !== 6'd8) begin err = err + 1; $display("UP FAIL %0d", time_count); end
        @(negedge clk); i_down = 1;
        @(negedge clk); i_down = 0;
        if (time_count !== 6'd7) begin err = err + 1; $display("DOWN FAIL %0d", time_count); end

        // down 7 번 -> 0, 한 번 더 -> 59, o_tick 안 나옴
        repeat (8) begin
            @(negedge clk); i_down = 1;
            @(negedge clk); i_down = 0;
            if (o_tick !== 1'b0) begin err = err + 1; $display("DOWN o_tick FAIL"); end
        end
        if (time_count !== 6'd59) begin err = err + 1; $display("DOWN WRAP FAIL %0d", time_count); end

        // up 으로 59 -> 0: o_tick 안 나옴 (올림 없음)
        @(negedge clk); i_up = 1;
        @(negedge clk); i_up = 0;
        if (time_count !== 6'd0 || o_tick !== 1'b0) begin err = err + 1; $display("UP WRAP FAIL %0d %b", time_count, o_tick); end

        // tick 으로 59 -> 0: o_tick 1 클럭
        @(negedge clk); i_down = 1;
        @(negedge clk); i_down = 0;          // 0 -> 59
        @(negedge clk); i_tick = 1;
        @(negedge clk); i_tick = 0;
        if (time_count !== 6'd0 || o_tick !== 1'b1) begin err = err + 1; $display("TICK WRAP FAIL %0d %b", time_count, o_tick); end
        @(negedge clk);
        if (o_tick !== 1'b0) begin err = err + 1; $display("o_tick not 1 clock"); end

        // (10/16) +-10: 0 -> 10, 55 -> 05, 05 -> 55 (60 으로 돌기), o_tick 안 나옴. tick 과 같은 클럭이면 tick 우선
        i_step10 = 1;
        @(negedge clk); i_up = 1;
        @(negedge clk); i_up = 0;
        if (time_count !== 6'd10 || o_tick !== 1'b0) begin err = err + 1; $display("UP10 FAIL %0d", time_count); end
        repeat (4) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end   // 10 -> 50
        i_step10 = 0; repeat (5) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end   // 50 -> 55
        i_step10 = 1;
        @(negedge clk); i_up = 1;
        @(negedge clk); i_up = 0;
        if (time_count !== 6'd5 || o_tick !== 1'b0) begin err = err + 1; $display("UP10 WRAP FAIL %0d %b", time_count, o_tick); end
        @(negedge clk); i_down = 1;
        @(negedge clk); i_down = 0;
        if (time_count !== 6'd55) begin err = err + 1; $display("DOWN10 WRAP FAIL %0d", time_count); end
        @(negedge clk); i_down = 1;
        @(negedge clk); i_down = 0;
        if (time_count !== 6'd45) begin err = err + 1; $display("DOWN10 FAIL %0d", time_count); end
        @(negedge clk); i_tick = 1; i_up = 1;
        @(negedge clk); i_tick = 0; i_up = 0;
        if (time_count !== 6'd46) begin err = err + 1; $display("PRIORITY step10 FAIL %0d", time_count); end
        i_step10 = 0;

        if (err == 0) $display("TOTAL MISMATCH = 0  (PASS)");
        else $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
