`timescale 1ns / 1ps
// sender_char_mux : 형식 번호 (i_sel) 와 글자 번호 (i_idx) 를 받아 그 자리의 ASCII 글자를 내는 조합 회로
module sender_char_mux (
    input      [ 2:0] i_sel,       // 0 · 1 · 2 = 시간, 3 = 거리, 4 = 온습도, 그 밖 = ERROR
    input      [23:0] i_data,      // 보낼 숫자 (형식마다 비트 배치가 다름 — 아래 자르기)
    input      [ 3:0] i_idx,       // 한 줄에서 몇 번째 글자인지 (0 부터)
    output reg [ 7:0] o_char,      // 그 자리 글자 (ASCII)
    output reg [ 3:0] o_last_idx   // 이 형식의 마지막 글자 번호 (FSM 이 끝 판단에 씀)
);
    localparam CR = 8'h0D, LF = 8'h0A;  // CR = 줄 맨 앞으로, LF = 다음 줄로

    // i_data 비트 배치 : 시간 {hour 5, min 6, sec 6, cs 7} / 거리 {status 2, cm 9} / 온습도 {err 1, dashes 1, status 2, hum 8, temp 8}
    wire [4:0] w_hour = i_data[23:19];
    wire [5:0] w_min  = i_data[18:13];
    wire [5:0] w_sec  = i_data[12:7];
    wire [6:0] w_cs   = i_data[6:0];    // 1/100 초 (0 ~ 99)
    wire [8:0] w_cm   = i_data[8:0];
    wire [1:0] w_dst  = i_data[10:9];   // (fix 10/31) 거리 상태 : 00 정상 · 01 Err1 · 10 Err2 · 11 Err3
    wire [1:0] w_hst  = i_data[17:16];  // (fix 10/31) 온습도 상태 : 01 Err1 · 10 Err2 · 11 Err3
    wire       w_hdash = i_data[18];    // (fix 10/31) 온습도 아직 정상값 없음 (FND "----")
    wire       w_herr  = i_data[19];    // (fix 10/31) 온습도 마지막 측정 실패 (FND "ErrN")
    wire [7:0] w_hum  = i_data[15:8];
    wire [7:0] w_temp = i_data[7:0];

    always @(*) begin
        o_char     = 8'h00;   // 기본값 : 아래에서 안 정하는 경로가 있어도 래치가 생기지 않게
        o_last_idx = 4'd0;
        case (i_sel)
            3'd0, 3'd1, 3'd2: begin   // 시간 "12:34:56.78" + CR LF (13 글자, 0 ~ 12)
                o_last_idx = 12;
                case (i_idx)          // 숫자 자리 = 8'h30 + 값 (8'h30 = "0")
                    4'd0: begin
                        o_char = 8'h30 + w_hour / 10;
                    end
                    4'd1: begin
                        o_char = 8'h30 + w_hour % 10;
                    end
                    4'd2: begin
                        o_char = ":";
                    end

                    4'd3: begin
                        o_char = 8'h30 + w_min / 10;
                    end
                    4'd4: begin
                        o_char = 8'h30 + w_min % 10;
                    end

                    4'd5: begin
                        o_char = ":";
                    end
                    4'd6: begin
                        o_char = 8'h30 + w_sec / 10;
                    end
                    4'd7: begin
                        o_char = 8'h30 + w_sec % 10;
                    end
                    4'd8: begin
                        o_char = ".";
                    end
                    4'd9: begin
                        o_char = 8'h30 + w_cs / 10;
                    end
                    4'd10: begin
                        o_char = 8'h30 + w_cs % 10;
                    end
                    4'd11: begin
                        o_char = CR;
                    end
                    4'd12: begin
                        o_char = LF;
                    end
                endcase
            end
            3'd3: begin               // 거리 "123cm" + CR LF (7 글자, 0 ~ 6), 오류면 "Err 2" + CR LF (fix 10/31)
                o_last_idx = 6;
                case (i_idx)
                    4'd0: begin
                        if (w_dst != 2'b00) o_char = "E";
                        else                o_char = 8'h30 + w_cm / 100;
                    end
                    4'd1: begin
                        if (w_dst != 2'b00) o_char = "r";
                        else                o_char = 8'h30 + (w_cm / 10) % 10;
                    end
                    4'd2: begin
                        if (w_dst != 2'b00) o_char = "r";
                        else                o_char = 8'h30 + w_cm % 10;
                    end
                    4'd3: begin
                        if (w_dst != 2'b00) o_char = " ";
                        else                o_char = "c";
                    end
                    4'd4: begin
                        if (w_dst != 2'b00) o_char = 8'h30 + w_dst;
                        else                o_char = "m";
                    end
                    4'd5: begin
                        o_char = CR;
                    end
                    4'd6: begin
                        o_char = LF;
                    end
                endcase
            end
            3'd4: begin               // 온습도 "45%25C" + CR LF (8 글자, 0 ~ 7)
                if (w_herr) begin         // (fix 10/31) 마지막 측정 실패 → "Err 1" + CR LF (7 글자, 거리 오류와 같은 꼴)
                    o_last_idx = 6;
                    case (i_idx)
                        4'd0: begin
                            o_char = "E";
                        end
                        4'd1: begin
                            o_char = "r";
                        end
                        4'd2: begin
                            o_char = "r";
                        end
                        4'd3: begin
                            o_char = " ";
                        end
                        4'd4: begin
                            o_char = 8'h30 + w_hst;
                        end
                        4'd5: begin
                            o_char = CR;
                        end
                        4'd6: begin
                            o_char = LF;
                        end
                    endcase
                end else begin
                    o_last_idx = 7;
                    case (i_idx)
                        4'd0: begin
                            if (w_hdash) o_char = "-";   // (fix 10/31) 첫 측정 전 → "--%--C"
                            else         o_char = 8'h30 + w_hum / 10;
                        end
                        4'd1: begin
                            if (w_hdash) o_char = "-";
                            else         o_char = 8'h30 + w_hum % 10;
                        end
                        4'd2: begin
                            o_char = "%";
                        end
                        4'd3: begin
                            if (w_hdash) o_char = "-";
                            else         o_char = 8'h30 + w_temp / 10;
                        end
                        4'd4: begin
                            if (w_hdash) o_char = "-";
                            else         o_char = 8'h30 + w_temp % 10;
                        end
                        4'd5: begin
                            o_char = "C";
                        end
                        4'd6: begin
                            o_char = CR;
                        end
                        4'd7: begin
                            o_char = LF;
                        end
                    endcase
                end
            end
            default: begin            // ERROR (7, 그리고 5 · 6) "ERROR" + CR LF (7 글자, 0 ~ 6)
                o_last_idx = 6;
                case (i_idx)
                    4'd0: begin
                        o_char = "E";
                    end
                    4'd1: begin
                        o_char = "R";
                    end
                    4'd2: begin
                        o_char = "R";
                    end
                    4'd3: begin
                        o_char = "O";
                    end
                    4'd4: begin
                        o_char = "R";
                    end
                    4'd5: begin
                        o_char = CR;
                    end
                    4'd6: begin
                        o_char = LF;
                    end
                endcase

            end
        endcase
    end
endmodule
