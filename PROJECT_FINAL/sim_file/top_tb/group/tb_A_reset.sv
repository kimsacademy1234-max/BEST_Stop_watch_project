`timescale 1ns / 1ps
// =============================================================================
// tb_A_reset — A. 리셋 · 공통 (tb_scenario.md A1 · A2)
//   A1 전원 · 리셋 직후 초기값   A2 동작 중 리셋
//   시간 : FAST = 1 이면 DHT 부팅 1 s → 10 ms, auto 1 Hz → 200 Hz, UART 115200, 센서 us tick 10 배
//          (WTS tick 은 원래 값 : FND 00.00 을 읽어야 해서)
//   실행 : README.md (Vivado : 이 파일 + tb_merge_harness.sv 를 Simulation Sources, 이 파일 Set as Top)
// =============================================================================
module tb_A_reset;
    localparam string ONLY = "";   // "" = 전부, "A2" = A2 만
    localparam bit    FAST = 1;    // 1 = 시간 줄임 (tb_scenario.md 3-3), 0 = 실제 시간

    tb_merge_harness #(
        .TICK_F    (1_000_000),
        .AUTO_FRQ  (FAST ? 200 : 1),
        .DHT_BOOT  (FAST ? 1_000_000 : 100_000_000),
        .DHT_INTV  (FAST ? 1_000_000 : 200_000_000),
        .BLINK_HALF(FAST ? 25_000 : 25_000_000),
        .BAUD      (FAST ? 115_200 : 9_600),
        .SR_TICK   (FAST ? 10 : 100),
        .DHT_TICK  (FAST ? 10 : 100),
        .TB_ID     ("A_reset"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 500 : 5_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;

    initial begin
        string   s;
        integer  n_tx0, n_trig0, n_dh0, n_ln0;
        realtime tend;
        bit      ok, dht_busy, tx_busy;

        // ---------------------------------------------------------------- A1
        if (h.run("A1")) begin
            h.begin_sc("A1", "power-on / reset initial values",
                       "switches 0 -> rst 1 us -> release; at 0.3 x boot: sw6 + R",
                       "w_rst 2 clk, FND 00.00, LED 8009, tx 1, trig 0, DHT START exactly at boot, no x/z");
            h.set_sw(7'b000_0000);
            h.sw15 = 0;
            h.do_reset();
            h.check("A1-1", h.rst_rel_clk == 2, "w_rst released N clk after rst falls", "2", $sformatf("%0d", h.rst_rel_clk));
            h.fnd_read(s);
            h.check("A1-2", s == "00.00", "FND right after reset (watch SS.CC, AN2 dot)", "\"00.00\"", {"\"", s, "\""});
            h.check("A1-3", h.led == 16'h8009, "LED (LD0 watch, LD3 SS.CC, LD15 PM)", "8009", $sformatf("%h", h.led));
            n_tx0   = h.n_tx_bytes;
            n_trig0 = h.trig_cnt;
            n_dh0   = h.dh_start_cnt;
            h.wait_until(h.t_rel + 0.3 * h.T_BOOT);
            h.set_sw(7'b100_0000);
            h.pulse_phy(BR);
            h.wait_until(h.t_rel + 1.5 * h.T_BOOT);
            h.check("A1-4", (h.n_tx_bytes == n_tx0) && (h.tx === 1'b1), "tx idle (no byte)", "0 byte, tx 1",
                    $sformatf("%0d byte, tx %b", h.n_tx_bytes - n_tx0, h.tx));
            h.check("A1-5", (h.trig_cnt == n_trig0) && (h.trig === 1'b0), "trig stays 0", "0 pulse",
                    $sformatf("%0d pulse", h.trig_cnt - n_trig0));
            h.check("A1-6", (h.dh_start_cnt == n_dh0 + 1) && (h.t_oe_r - (h.t_rel + h.T_BOOT) >= 0)
                            && (h.t_oe_r - (h.t_rel + h.T_BOOT) <= 100.0),
                    "DHT line high until boot, START (R at 0.3 boot) begins at boot",
                    $sformatf("1 START at release + %0.3f ms", h.T_BOOT / 1.0e6),
                    $sformatf("%0d START at release + %0.6f ms", h.dh_start_cnt - n_dh0, (h.t_oe_r - h.t_rel) / 1.0e6));
            h.check("A1-7", !h.xz_seen, "no x/z on led/fnd/tx/trig after release", "none",
                    h.xz_str());
        end

        // ---------------------------------------------------------------- A2
        if (h.run("A2")) begin
            h.begin_sc("A2", "reset while everything is running",
                       "SW RUN + /auto all + SR04 auto + DHT START LOW + ERROR line on tx -> rst",
                       "at rst: tx 1, trig 0, DHT line released; after: switch mode, all initial, DHT boot again");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("s_ms");
            h.ubtn("R");
            h.uart_send("/auto all");
            h.mod("dist");
            h.ubtn("U");
            h.mod("temp");
            h.wait_until(h.t_rel + 1.1 * h.T_BOOT);
            h.ubtn("R");
            tend = $realtime + 100 * h.MS;
            while ((h.dut.U_DHT11.w_dht_oe !== 1'b1) && ($realtime < tend)) #(1 * h.US);
            h.uart_send("/gx");                // 'x' 에서 ERROR → START LOW 동안 tx 송신 중
            h.wait_us(500);
            dht_busy = h.dut.U_DHT11.w_dht_oe;
            tx_busy  = h.dut.U_UART.w_tx_busy;
            h.note($sformatf("just before rst : DHT START LOW %b, uart_tx busy %b, SW run %b, SR04 auto %b",
                             dht_busy, tx_busy, h.dut.U_WTS.w_sw_run_stop, h.dut.w_dist_auto));
            h.rst_assert();
            #1;
            h.check("A2-1", h.tx === 1'b1, "tx goes high immediately on rst", "1", $sformatf("%b", h.tx));
            h.check("A2-2", h.trig === 1'b0, "trig 0 immediately on rst", "0", $sformatf("%b", h.trig));
            h.check("A2-3", (h.dht11_io === 1'b1) && (h.dut.U_DHT11.w_dht_oe === 1'b0),
                    "DHT line released immediately on rst", "oe 0, line 1",
                    $sformatf("oe %b, line %b (was START LOW %b)", h.dut.U_DHT11.w_dht_oe, h.dht11_io, dht_busy));
            #(1 * h.US);
            h.rst_release();
            h.check("A2-4", (h.dut.w_uart_mode == 0) && (h.dut.w_disp_sel == 0) && (h.dut.w_sel_wt == 1),
                    "back to switch mode (switches 0 = watch)", "uart_mode 0, watch",
                    $sformatf("uart_mode %b, disp_sel %0d, sel_wt %b", h.dut.w_uart_mode, h.dut.w_disp_sel, h.dut.w_sel_wt));
            h.check("A2-5", (h.sw_cnt_cs() == 0) && (h.dut.U_WTS.w_sw_run_stop == 0) && (h.wt_cs() == h.hms2cs(12, 0, 0, 0))
                            && (h.tm_cs() == 0) && (h.dut.w_tm_run == 0) && (h.dut.w_tm_alarm == 0),
                    "WTS initial", "SW 0 STOP, watch 12:00:00.00, timer 0 SET",
                    $sformatf("SW %s run %b, watch %s, timer %s run %b", h.cs2str(h.sw_cnt_cs()), h.dut.U_WTS.w_sw_run_stop,
                              h.cs2str(h.wt_cs()), h.cs2str(h.tm_cs()), h.dut.w_tm_run));
            // A2-7 : 해제 직후 온습도 화면 + R → START 는 다시 boot 뒤
            n_dh0 = h.dh_start_cnt;
            h.set_sw(7'b100_0000);
            h.pulse_phy(BR);
            n_tx0   = h.n_tx_bytes;
            n_trig0 = h.trig_cnt;
            h.wait_until(h.t_rel + 3.0 * h.T_AUTO);
            h.check("A2-6", (h.n_tx_bytes == n_tx0) && (h.trig_cnt == n_trig0) && (h.dut.w_dht_led[3] == 0)
                            && (h.dut.w_dist_auto == 0),
                    "auto off: no tx line for 3 auto periods, SR04 / DHT auto off", "0 byte, 0 trig, auto 0",
                    $sformatf("%0d byte, %0d trig, dist_auto %b, dht_auto %b", h.n_tx_bytes - n_tx0,
                              h.trig_cnt - n_trig0, h.dut.w_dist_auto, h.dut.w_dht_led[3]));
            h.check("A2-7", (h.dh_start_cnt == n_dh0 + 1) && (h.t_oe_r - (h.t_rel + h.T_BOOT) >= 0)
                            && (h.t_oe_r - (h.t_rel + h.T_BOOT) <= 100.0),
                    "DHT waits boot again after reset", $sformatf("START at release + %0.3f ms", h.T_BOOT / 1.0e6),
                    $sformatf("%0d START at release + %0.6f ms", h.dh_start_cnt - n_dh0, (h.t_oe_r - h.t_rel) / 1.0e6));
        end

        h.finish_tb();
    end
endmodule
