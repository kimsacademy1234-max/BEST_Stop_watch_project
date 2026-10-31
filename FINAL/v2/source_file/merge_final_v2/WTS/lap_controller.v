`timescale 1ns / 1ps

// 랩 컨트롤러 (v2 포트 통일) — stopwatch_datapath 안
// i_cnt_* : 카운터 실제 값, o_sw_* : 화면으로 나가는 값 (랩 중이면 저장값)
module lap_controller (
    input        i_clk,
    input        i_rst,
    input        i_sw_clear,
    input        i_sw_btn_D,  // 랩 버튼

    input  [6:0] i_cnt_msec,
    input  [5:0] i_cnt_sec,
    input  [5:0] i_cnt_min,
    input  [4:0] i_cnt_hour,

    output [6:0] o_sw_msec,
    output [5:0] o_sw_sec,
    output [5:0] o_sw_min,
    output [4:0] o_sw_hour,
    output       o_sw_lap
);

    // LAP 상태 및 시간 저장
    reg lap_enable;

    reg [6:0] save_msec;
    reg [5:0] save_sec;
    reg [5:0] save_min;
    reg [4:0] save_hour;

    always @(posedge i_clk or posedge i_rst) begin
        // Reset 초기화
        if (i_rst) begin
            lap_enable <= 1'b0;
            save_msec <= 0;
            save_sec <= 0;
            save_min <= 0;
            save_hour <= 0;
        end
        // Clear 초기화
        else if (i_sw_clear) begin
            lap_enable <= 1'b0;
            save_msec <= 0;
            save_sec <= 0;
            save_min <= 0;
            save_hour <= 0;
        end
        else begin
            // LAP 버튼 입력 시 상태 전환
            if (i_sw_btn_D) begin
                lap_enable <= ~lap_enable;

                // LAP 활성화 시 현재 시간 저장
                if (!lap_enable) begin
                    save_msec <= i_cnt_msec;
                    save_sec <= i_cnt_sec;
                    save_min <= i_cnt_min;
                    save_hour <= i_cnt_hour;
                end
            end
        end
    end

    // LAP 활성화 시 저장된 시간 출력
    // 비활성화 시 현재 시간 출력
    assign o_sw_msec = lap_enable ? save_msec : i_cnt_msec;
    assign o_sw_sec  = lap_enable ? save_sec  : i_cnt_sec;
    assign o_sw_min  = lap_enable ? save_min  : i_cnt_min;
    assign o_sw_hour = lap_enable ? save_hour : i_cnt_hour;

    // LAP 활성화 상태 출력
    assign o_sw_lap = lap_enable;

endmodule
