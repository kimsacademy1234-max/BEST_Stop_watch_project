`timescale 1ns / 1ps
// =============================================================================
// fnd_monitor — FND 출력 해석기 + 참조 모델 비교기
//   * 참조 모델은 FND 입력(sel · 화면값 · 점멸 조건)으로 "지금 나와야 할 com/font" 를 계산
//   * 출력이 참조와 다른 구간(mm)을 시간 단위로 잼 → 구간 끝날 때 mm_count++
//   * 고스트(ghost): com 이 참조와 다른데(다른 자리가 켜져 있는데) 숫자/DP 가 켜진 구간 → 자리별 누적 시간
//   * disp_str: 매 슬롯 200 us 시점의 출력을 모아 "12.34" 형식 (빈칸 '_'), disp_dp = AN2 DP 켜짐
// =============================================================================
//   * (v2) 입력 이름 = U_FND_CONTROLLER 입력 포트 이름 (i_disp_*, i_wt_cursor, i_sel_wt, i_set_sw2)
//          + U_COUNTER8.o_scan_sel(w_scan_sel), Top 출력 fnd_com / fnd_font
module fnd_monitor (
    input [3:0] i_fnd_com,
    input [7:0] i_fnd_font,
    input [2:0] i_scan_sel,
    input       i_disp_mode,
    input [5:0] i_disp_hour,
    input [5:0] i_disp_min,
    input [5:0] i_disp_sec,
    input [6:0] i_disp_msec,
    input [1:0] i_wt_cursor,
    input       i_set_sw2,
    input       i_sel_wt     // 1 = 시계 화면
);
    // 아래 본문은 짧은 이름으로 씀
    wire [3:0] com = i_fnd_com;
    wire [7:0] font = i_fnd_font;
    wire [2:0] sel = i_scan_sel;
    wire       disp_mode = i_disp_mode;
    wire [5:0] hour = i_disp_hour, min = i_disp_min, sec = i_disp_sec;
    wire [6:0] msec = i_disp_msec;
    wire [1:0] cursor = i_wt_cursor;

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
        blink = i_set_sw2 & disp_mode & i_sel_wt & (msec >= 50) & (cursor != 2'd3);
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

    // ------------------------------------------------------------ 숫자 · 자리 이름으로 보기 (파형용)
    //   an_name  : fnd_com → "AN0"~"AN3" (모두 꺼짐 1111 = "---", 두 자리 이상 켜짐 = "ERR")
    //   fnd_an   : 지금 켜진 자리 이름. 파형 Radix = ASCII 로 두면 글자로 보임
    //   font2num : 7-seg 코드(active-low) → 숫자 0~9. 빈칸 FF = F, 점만 7F = E, 그 밖 = A
    //   fnd_num  : 지금 켜진 자리(fnd_com 의 0)의 숫자. Radix = Hexadecimal (0~9, 빈칸 F)
    //   disp_bcd : 화면 4 자리 {AN3, AN2, AN1, AN0} 를 BCD 로 (disp_str 과 같은 순간에 갱신)
    //              Radix = Hexadecimal 이면 화면 그대로 "1234" 로 읽힘 (빈칸 자리는 F, 예 "123F")
    function automatic [3:0] font2num(input [7:0] f);
        case (f)
            8'hC0: font2num = 4'h0; 8'hF9: font2num = 4'h1; 8'hA4: font2num = 4'h2; 8'hB0: font2num = 4'h3;
            8'h99: font2num = 4'h4; 8'h92: font2num = 4'h5; 8'h82: font2num = 4'h6; 8'hF8: font2num = 4'h7;
            8'h80: font2num = 4'h8; 8'h90: font2num = 4'h9; 8'hFF: font2num = 4'hF; 8'h7F: font2num = 4'hE;
            default: font2num = 4'hA;
        endcase
    endfunction

    function automatic [23:0] an_name(input [3:0] c);
        case (c)
            4'b1110: an_name = "AN0"; 4'b1101: an_name = "AN1"; 4'b1011: an_name = "AN2"; 4'b0111: an_name = "AN3";
            4'b1111: an_name = "---";
            default: an_name = "ERR";
        endcase
    endfunction

    wire [23:0] fnd_an   = an_name(com);
    wire [3:0]  fnd_num  = font2num(font);
    wire [15:0] disp_bcd = {font2num(seen[3]), font2num(seen[2]), font2num(seen[1]), font2num(seen[0])};

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
