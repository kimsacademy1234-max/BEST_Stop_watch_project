`timescale 1ns / 1ps

module lap_controller (
    input clk,
    input rst,
    input clear,
    input btn_lap,

    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,

    output [6:0] disp_msec,
    output [5:0] disp_sec,
    output [5:0] disp_min,
    output [4:0] disp_hour,
    output lap_active
);

    // LAP 상태 및 시간 저장
    reg lap_enable;

    reg [6:0] save_msec;
    reg [5:0] save_sec;
    reg [5:0] save_min;
    reg [4:0] save_hour;

    always @(posedge clk or posedge rst) begin
        // Reset 초기화
        if (rst) begin
            lap_enable <= 1'b0;
            save_msec <= 0;
            save_sec <= 0;
            save_min <= 0;
            save_hour <= 0;
        end 
        // Clear 초기화
        else if (clear) begin
            lap_enable <= 1'b0;
            save_msec <= 0;
            save_sec <= 0;
            save_min <= 0;
            save_hour <= 0;
        end 
        else begin
            // LAP 버튼 입력 시 상태 전환
            if (btn_lap) begin
                lap_enable <= ~lap_enable;

                // LAP 활성화 시 현재 시간 저장
                if (!lap_enable) begin
                    save_msec <= msec;
                    save_sec <= sec;
                    save_min <= min;
                    save_hour <= hour;
                end
            end
        end
    end

    // LAP 활성화 시 저장된 시간 출력
    // 비활성화 시 현재 시간 출력
    assign disp_msec = lap_enable ? save_msec : msec;
    assign disp_sec  = lap_enable ? save_sec  : sec;
    assign disp_min  = lap_enable ? save_min  : min;
    assign disp_hour = lap_enable ? save_hour : hour;

    // LAP 활성화 상태 출력
    assign lap_active = lap_enable;

endmodule