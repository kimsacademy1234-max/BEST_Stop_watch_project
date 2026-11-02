`timescale 1ns / 1ps
// tick_gen_1us 단위 TB (enable · clear 판) — 100 MHz 에서 1 us 마다 1 클럭 tick
//  (1) enable 0 → tick 없음        (2) enable 켠 뒤 100 클럭째 첫 tick (= 1 us)
//  (3) tick 폭 1 클럭 · 다음 tick 까지 100 클럭
//  (4) tick 직후 enable 0 → tick 이 1 로 남지 않음 · 멈춤
//  (5) 세는 도중 clear 1 클럭 → clear 뒤 100 클럭째 tick (처음부터 다시)
module tb_sr1_tick ();
    reg clk, rst, en, clr;
    wire tick;
    integer err, k, ok, n;

    tick_gen_1us #(.F_COUNT(100)) dut (
        .clk     (clk),
        .rst     (rst),
        .i_enable(en),
        .i_clear (clr),
        .o_tick  (tick)
    );

    always #5 clk = ~clk;

    // tick 이 올 때까지 클럭 수 세기 (최대 300)
    task clocks_to_tick;
        begin
            k = 0; ok = 0;
            while (ok == 0 && k < 300) begin
                @(posedge clk); #1; k = k + 1;
                if (tick === 1'b1) ok = 1;
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; en = 0; clr = 0; err = 0; n = 0;
        #20 rst = 0;

        // (1) enable 0 동안 5 us → tick 0 번
        repeat (500) begin @(posedge clk); #1; if (tick === 1'b1) n = n + 1; end
        if (n !== 0) begin err = err + 1; $display("%t (1) MISMATCH enable 0 인데 tick %0d 번", $time, n); end
        else $display("%t (1) enable 0 → tick 없음", $time);

        // (2) clear 1 클럭 → enable 1 → 100 클럭째 첫 tick
        @(negedge clk); clr = 1;
        @(negedge clk); clr = 0; en = 1;
        clocks_to_tick;
        if (k !== 100) begin err = err + 1; $display("%t (2) MISMATCH 첫 tick 까지 %0d 클럭 (expect 100)", $time, k); end
        else $display("%t (2) enable 뒤 첫 tick %0d 클럭 (1 us)", $time, k);

        // (3) 폭 1 클럭 · 다음 tick 100 클럭
        @(posedge clk); #1;
        if (tick !== 1'b0) begin err = err + 1; $display("%t (3) MISMATCH tick 폭 2 클럭 이상", $time); end
        clocks_to_tick;
        if (k !== 99) begin err = err + 1; $display("%t (3) MISMATCH tick 간격 %0d 클럭 (expect 100)", $time, k + 1); end
        else $display("%t (3) tick 폭 1 클럭, 간격 %0d 클럭", $time, k + 1);

        // (4) tick 이 1 인 클럭에 enable 0 → 다음 클럭부터 tick 0 이고 멈춤
        @(negedge clk); en = 0;
        n = 0;
        repeat (300) begin @(posedge clk); #1; if (tick === 1'b1) n = n + 1; end
        if (n !== 0) begin err = err + 1; $display("%t (4) MISMATCH enable 끈 뒤 tick 1 이 %0d 클럭", $time, n); end
        else $display("%t (4) enable 끈 뒤 tick 0 (멈춤)", $time);

        // (5) 다시 켜고 50 클럭 센 뒤 clear 1 클럭 → clear 뒤 100 클럭째 tick
        @(negedge clk); en = 1;
        repeat (50) @(negedge clk);
        clr = 1;
        @(negedge clk); clr = 0;
        clocks_to_tick;
        if (k !== 100) begin err = err + 1; $display("%t (5) MISMATCH clear 뒤 첫 tick %0d 클럭 (expect 100)", $time, k); end
        else $display("%t (5) 세는 도중 clear → %0d 클럭째 tick (처음부터)", $time, k);

        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
