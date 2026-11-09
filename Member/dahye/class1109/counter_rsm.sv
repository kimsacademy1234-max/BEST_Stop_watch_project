`timescale 1ns / 1ps



module counter_rsm(


input logic i_clk , 
input logic i_reset ,
input logic i_run_stop ,
input logic i_mode ,
input logic i_clear ,
output logic [7:0] o_count



);




always_ff@(posedge i_clk or posedge i_reset)begin


	if(i_reset)begin				// 비동기 reset : 감지 목록(posedge i_reset)과 일치
			o_count <= 8'd0;
	end

	else if(i_clear)begin			// 동기 clear : 클럭 엣지에서만 동작
			o_count <= 8'd0;
	end

	else begin

		if(i_run_stop)begin

			if(i_mode) o_count <= o_count - 1;	// mode = 1 : down

			else o_count <= o_count + 1;		// mode = 0 : up
		end

	end



end

endmodule
