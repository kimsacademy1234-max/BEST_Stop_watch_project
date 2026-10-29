`timescale 1ns / 1ps

module fnd_controller (
    input clk,
    input reset,
    input [13:0] fnd_data,  // 9bit {c, s}
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    wire [3:0] w_ds1, w_ds10, w_ds100, w_ds1000, w_mux_out;
    wire [1:0] w_ds_sel;
    wire w_clk_800hz;

    clk_div_800hz U_CLK_DIV_800HZ (
    .clk(clk),
    .reset(reset),
    .o_clk_800hz(w_clk_800hz)
);

    counter_4 U_COUNTER_4 (
        .clk(w_clk_800hz),
        .reset(reset),
        .ds_sel(w_ds_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .ds_sel (w_ds_sel),
        .fnd_com(fnd_com)
    );

    digit_splitter U_DIGIT_SPLITTER (
        .dsin(fnd_data),
        .ds1(w_ds1),  // digit 1 
        .ds10(w_ds10),  // digit 10 
        .ds100(w_ds100),  // digit 100 
        .ds1000(w_ds1000)  // digit 1000 
    );

    mux_4x1 U_MUX_4x1 (
        .sel(w_ds_sel),
        .in0(w_ds1),
        .in1(w_ds10),
        .in2(w_ds100),
        .in3(w_ds1000),
        .mux_out(w_mux_out)
    );


    bcd U_BCD (
        .bin(w_mux_out),
        .fnd_font(fnd_font)   // 값을 유지해서 내보내야 하므로 reg로 선언. 
    );
endmodule



module clk_div_800hz (
    input clk,
    input reset,
    output reg o_clk_800hz
);

    reg [$clog2(62_500)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 16'd0;
            o_clk_800hz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (62_500 - 1)) begin
                counter_reg <= 16'd0;
                o_clk_800hz <= ~o_clk_800hz;
            end
        end
    end
endmodule



module counter_4 (
    input clk,
    input reset,
    output [1:0] ds_sel
);
    reg [1:0] counter_reg;

    assign ds_sel = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            // reset: 1'b1
            counter_reg <= 2'b0; // 1의 자리부터 보여줌. 10의 자리부터 보여주고싶으면 2'b1로 리셋.
        end else begin
            //operation
            counter_reg <= counter_reg + 1;
        end
    end


endmodule

module decoder_2x4 (
    input [1:0] ds_sel,
    output reg [3:0] fnd_com
);

    always @(ds_sel) begin
        case (ds_sel)
            2'b00: fnd_com = 4'b1110;
            2'b01: fnd_com = 4'b1101;
            2'b10: fnd_com = 4'b1011;
            2'b11: fnd_com = 4'b0111;
            default:
            fnd_com = 4'b1111; // 잘못된 경우 다 끄기. 그래서 잘못된 경우 인지할 수 있음. 
        endcase
    end

endmodule

module mux_4x1 (
    input [1:0] sel,
    input [3:0] in0,
    input [3:0] in1,
    input [3:0] in2,
    input [3:0] in3,
    output reg [3:0] mux_out
);

    always @(*) begin  // * : all input sensitivity list
        case (sel)
            2'b00:   mux_out = in0;
            2'b01:   mux_out = in1;
            2'b10:   mux_out = in2;
            2'b11:   mux_out = in3;
            default: mux_out = in0;
        endcase
    end

endmodule

module digit_splitter (
    input  [13:0] dsin,
    output [3:0] ds1,    // digit 1 
    output [3:0] ds10,   // digit 10 
    output [3:0] ds100,  // digit 100 
    output [3:0] ds1000  // digit 1000 
);

    assign ds1 = dsin % 10;  // 나머지 연산자 %
    assign ds10 = (dsin / 10) % 10;  // 나머지 연산자 %, digit 10
    assign ds100 = (dsin / 100) % 10;  // 나머지 연산자 %, digit 100
    assign ds1000 = (dsin / 1000) % 10;  // 나머지 연산자 %, digit 10

endmodule


module bcd (
    input [3:0] bin,
    output reg [7:0] fnd_font   // 값을 유지해서 내보내야 하므로 reg로 선언. 
);

    always @(bin) begin
        case (bin)
            4'b0000: fnd_font = 8'hc0;
            4'b0001: fnd_font = 8'hf9;
            4'b0010: fnd_font = 8'ha4;
            4'b0011: fnd_font = 8'hb0;
            4'b0100: fnd_font = 8'h99;
            4'b0101: fnd_font = 8'h92;
            4'b0110: fnd_font = 8'h82;
            4'b0111: fnd_font = 8'hf8;
            4'b1000: fnd_font = 8'h80;
            4'b1001: fnd_font = 8'h90;
            4'b1010: fnd_font = 8'h88;
            4'b1011: fnd_font = 8'h83;
            4'b1100: fnd_font = 8'hc6;
            4'b1101: fnd_font = 8'ha1;
            4'b1110: fnd_font = 8'h86;
            4'b1111: fnd_font = 8'h8e;
            default: fnd_font = 8'hff;
        endcase

    end

endmodule

