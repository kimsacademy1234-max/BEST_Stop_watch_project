`timescale 1ns / 1ps

// FIFO (register file + control unit)
// (merge) RX 쪽 fifo.sv (i_clk / i_reset) 와 TX 쪽 fifo.v (clk / rst) 는 같은 동작이라 하나로 합침
//         - 포트 이름 v2 규칙 (i_ / o_)
//         - 하위 모듈 이름 control_unit / register_file → fifo_control_unit / fifo_register_file
//           (다른 control_unit 과 이름이 겹치지 않게)
//         - register_file 의 reg[7:0] 고정 → BIT_WIDTH
module fifo #(
    parameter DEPTH          = 4,
    parameter BIT_WIDTH      = 8,
    parameter ADDR_BIT_WIDTH = $clog2(DEPTH)
) (
    input                  i_clk,
    input                  i_rst,
    input                  i_push,
    input                  i_pop,
    input  [BIT_WIDTH-1:0] i_push_data,
    output [BIT_WIDTH-1:0] o_pop_data,
    output                 o_full,
    output                 o_empty
);

    wire [ADDR_BIT_WIDTH-1:0] w_wptr, w_rptr;

    fifo_control_unit #(
        .ADDR_BIT_WIDTH(ADDR_BIT_WIDTH)
    ) U_FIFO_CONTROL_UNIT (
        .i_clk  (i_clk),
        .i_rst  (i_rst),
        .i_push (i_push),
        .i_pop  (i_pop),
        .o_wptr (w_wptr),
        .o_rptr (w_rptr),
        .o_full (o_full),
        .o_empty(o_empty)
    );

    fifo_register_file #(
        .DEPTH    (DEPTH),
        .BIT_WIDTH(BIT_WIDTH)
    ) U_FIFO_REG_FILE (
        .i_clk  (i_clk),
        .i_we   (~o_full & i_push),
        .i_wdata(i_push_data),
        .i_waddr(w_wptr),
        .i_raddr(w_rptr),
        .o_rdata(o_pop_data)
    );

endmodule


module fifo_control_unit #(
    parameter ADDR_BIT_WIDTH = 2
) (
    input                       i_clk,
    input                       i_rst,
    input                       i_push,
    input                       i_pop,
    output [ADDR_BIT_WIDTH-1:0] o_wptr,
    output [ADDR_BIT_WIDTH-1:0] o_rptr,
    output                      o_full,
    output                      o_empty
);

    reg [ADDR_BIT_WIDTH-1:0] wptr_reg, wptr_next;
    reg [ADDR_BIT_WIDTH-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign o_wptr  = wptr_reg;
    assign o_rptr  = rptr_reg;
    assign o_full  = full_reg;
    assign o_empty = empty_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({i_push, i_pop})
            2'b10: begin
                // push only
                if (!full_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) full_next = 1'b1;
                end
            end
            2'b01: begin
                // pop only
                if (!empty_reg) begin
                    full_next = 1'b0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) empty_next = 1'b1;
                end
            end
            2'b11: begin
                // push / pop
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

endmodule


module fifo_register_file #(
    parameter DEPTH          = 4,
    parameter ADDR_BIT_WIDTH = $clog2(DEPTH),
    parameter BIT_WIDTH      = 8
) (
    input                       i_clk,
    input                       i_we,
    input  [     BIT_WIDTH-1:0] i_wdata,
    input  [ADDR_BIT_WIDTH-1:0] i_waddr,
    input  [ADDR_BIT_WIDTH-1:0] i_raddr,
    output [     BIT_WIDTH-1:0] o_rdata
);

    reg [BIT_WIDTH-1:0] register_file[0:DEPTH-1];

    always @(posedge i_clk) begin
        if (i_we) register_file[i_waddr] <= i_wdata;
    end

    assign o_rdata = register_file[i_raddr];

endmodule
