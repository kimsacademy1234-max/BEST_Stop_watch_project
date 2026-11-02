`timescale 1ns / 1ps
// Assert asynchronously, release synchronously. INIT also resets at power-up.
module reset_sync (
    input wire clk, reset_button,
    output wire rst
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;
    always @(posedge clk or posedge reset_button)
        if (reset_button) reset_pipe <= 2'b11;
        else reset_pipe <= {reset_pipe[0], 1'b0};
    assign rst = reset_pipe[1];
endmodule
