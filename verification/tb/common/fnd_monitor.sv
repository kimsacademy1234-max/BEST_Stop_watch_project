`timescale 1ns / 1ps
// =============================================================================
// fnd_monitor — FND 출력 해석기 + 참조 모델 비교기 (verification.md §5.2)
//   * 참조 모델은 FND 입력(sel · 화면값 · 점멸 조건)으로 "지금 나와야 할 com/font" 를 계산
//   * 출력이 참조와 다른 구간(mm)을 시간 단위로 잼 → 구간 끝날 때 mm_count++
//   * 고스트(ghost): com 이 참조와 다른데(다른 자리가 켜져 있는데) 숫자/DP 가 켜진 구간 → 자리별 누적 시간
//   * disp_str: 매 슬롯 200 us 시점의 출력을 모아 "12.34" 형식 (빈칸 '_'), disp_dp = AN2 DP 켜짐
// =============================================================================
module fnd_monitor (
    input [3:0] com,
    input [7:0] font,
    input [2:0] sel,
    input       disp_mode,
    input [5:0] hour,
    input [5:0] min,
    input [5:0] sec,
    input [6:0] msec,
    input [1:0] cursor,
    input       sw_set,
    input       sw_scr      // sw_mode | sw_timer (시계 화면이 아님)
);
    // ------------------------------------------------------------ 참조 모델
    function automatic [7:0] seg(input [3:0] d);
        case (d)
            4'h0: seg = 8'hC0; 4'h1: seg = 8'hF9; 4'h2: seg = 8'hA4; 4'h3: seg = 8'hB0;
            4'h4: seg = 8'h99; 4'h5: seg = 8'h92; 4'h6: seg = 8'h82; 4'h7: seg = 8'hF8;
            4'h8: seg = 8'h80; 4'h9: seg = 8'h90; 4'hd: seg = 8'hFF; 4'he: seg = 8'h7F;
            4'hf: seg = 8'hFF; default: seg = 8'hC0;
        endcase
    endfunction

    reg [3:0] d0, d1, d2, d3, x;
    reg       blink;
    reg [7:0] exp_font;
    reg [3:0] exp_com;
    always @* begin
        blink = sw_set & disp_mode & ~sw_scr & (msec >= 50) & (cursor != 2'd3);
        if (disp_mode) begin
            d3 = (hour / 10) % 10; d2 = hour % 10; d1 = (min / 10) % 10; d0 = min % 10;
        end else begin
            d3 = (sec / 10) % 10;  d2 = sec % 10;  d1 = (msec / 10) % 10; d0 = msec % 10;
        end
        if (blink) begin
            case (cursor)
                2'd0: d0 = 4'hd;
                2'd1: d1 = 4'hd;
                2'd2: d2 = 4'hd;
                default: ;
            endcase
        end
        case (sel)
            3'd0: x = d0;
            3'd1: x = d1;
            3'd2: x = d2;
            3'd3: x = d3;
            3'd6: x = {3'b111, (msec >= 50)};
            default: x = 4'hf;
        endcase
        exp_font = seg(x);
        exp_com  = ~(4'b0001 << sel[1:0]);
    end

    function automatic integer an_of(input [3:0] c);
        case (c)
            4'b1110: an_of = 0; 4'b1101: an_of = 1; 4'b1011: an_of = 2; 4'b0111: an_of = 3;
            default: an_of = -1;
        endcase
    endfunction

    function automatic string ch(input [7:0] f);
        case (f)
            8'hC0: ch = "0"; 8'hF9: ch = "1"; 8'hA4: ch = "2"; 8'hB0: ch = "3"; 8'h99: ch = "4";
            8'h92: ch = "5"; 8'h82: ch = "6"; 8'hF8: ch = "7"; 8'h80: ch = "8"; 8'h90: ch = "9";
            8'hFF: ch = "_"; 8'h7F: ch = "."; default: ch = "?";
        endcase
    endfunction

    // ------------------------------------------------------------ 불일치 구간
    wire mm     = (com !== exp_com) || (font !== exp_font);
    wire onehot = (an_of(com) >= 0);
    wire ghost  = onehot && (com !== exp_com) && (font !== 8'hFF);

    integer  mm_count = 0;
    realtime mm_t0 = 0, mm_last_t = 0, mm_last_dur = 0, mm_total = 0;
    string   mm_desc = "";
    always @(mm) begin
        if (mm) begin
            mm_t0 = $realtime;
            mm_desc = $sformatf("slot=%0d com=%b exp_com=%b font=%h(%s) exp_font=%h(%s)",
                                sel, com, exp_com, font, ch(font), exp_font, ch(exp_font));
        end else if ($realtime - mm_t0 > 0.5) begin
            mm_last_t   = mm_t0;
            mm_last_dur = $realtime - mm_t0;
            mm_total    = mm_total + mm_last_dur;
            mm_count    = mm_count + 1;
        end
    end

    // ------------------------------------------------------------ 고스트 (F1)
    realtime ghost_time[0:3];
    integer  ghost_n[0:3];
    reg [7:0] ghost_font[0:3];
    realtime g_t0 = 0;
    realtime ghost_first_t = -1;   // clear_stats() 뒤 첫 고스트 시각
    integer  g_an = -1;
    reg [7:0] g_font = 8'hFF;
    initial clear_stats();

    always @(ghost) begin
        if (ghost) begin
            g_t0   = $realtime;
            if (ghost_first_t < 0) ghost_first_t = $realtime;
            g_an   = an_of(com);
            g_font = font;
        end else if (g_an >= 0 && ($realtime - g_t0) > 0.5) begin
            ghost_time[g_an] = ghost_time[g_an] + ($realtime - g_t0);
            ghost_n[g_an]    = ghost_n[g_an] + 1;
            ghost_font[g_an] = g_font;
        end
    end

    // ------------------------------------------------------------ one-hot 검사
    integer onehot_err = 0;
    always @(com) begin
        #1;
        if (!onehot) onehot_err = onehot_err + 1;
    end

    // ------------------------------------------------------------ 화면 문자열
    reg [7:0] seen[0:3];
    reg       disp_dp = 1'b0;
    string    disp_str = "__.__";
    integer   frames = 0, dp_frames = 0;
    initial begin seen[0] = 8'hFF; seen[1] = 8'hFF; seen[2] = 8'hFF; seen[3] = 8'hFF; end
    always @(sel) begin
        #200000;  // 슬롯(250 us) 안 200 us 시점
        if (sel < 4) seen[sel] = font;
        if (sel == 3'd3) disp_str = $sformatf("%s%s.%s%s", ch(seen[3]), ch(seen[2]), ch(seen[1]), ch(seen[0]));
        if (sel == 3'd6) begin
            disp_dp = (font == 8'h7F);
            frames  = frames + 1;
            if (disp_dp) dp_frames = dp_frames + 1;
        end
    end

    task automatic clear_stats();
        integer i;
        for (i = 0; i < 4; i = i + 1) begin
            ghost_time[i] = 0;
            ghost_n[i]    = 0;
            ghost_font[i] = 8'hFF;
        end
        frames = 0;
        dp_frames = 0;
        ghost_first_t = -1;
    endtask
endmodule
