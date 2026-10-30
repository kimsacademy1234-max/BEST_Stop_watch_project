`timescale 1ns / 1ps


module UART_ASCII_DECODER#(

        parameter BIT_WIDTH = 8,
        parameter DATA_WIDTH = 32

        )(

    input i_clk,i_reset,
    input[BIT_WIDTH-1:0] i_ascii,
    input i_enable,
    output o_error,
    output o_pop,
    output o_handshake,
    output o_get,
    output o_btn,
	output o_set,
	output o_off_set,
    output o_mode,
    output o_auto,
    output[DATA_WIDTH-1:0] o_ascii

);

localparam [BIT_WIDTH-1:0] START_CHAR = "/";
localparam [BIT_WIDTH-1:0] CR = 8'h0D;
localparam [BIT_WIDTH-1:0] LF = 8'h0A;
localparam OPT_LEN = 4;


typedef enum logic [3:0] {
    IDLE,
    SLASH,
    SPACE,

    g, e, t,

    m, o, d,

    b, n,

    a, u,

	s,f

} state_t;

state_t n_state,c_state;

reg [DATA_WIDTH-1:0] data_reg, n_data_reg;
reg get_state,n_get_state;
reg btn_state,n_btn_state;
reg mode_state,n_mode_state;
reg auto_state,n_auto_state;
reg set_state,n_set_state;
reg off_state,n_off_state;

reg [2:0] done_cnt, n_done_cnt;
reg handshake,n_handshake;
reg error,n_error;
reg bad, done;
reg off,n_off;

wire w_byte = i_enable;




assign o_ascii = (o_handshake)? data_reg : 0;
assign o_pop = w_byte;
assign o_error = error;
assign o_handshake = handshake;
assign o_get = get_state;
assign o_btn = btn_state;
assign o_mode = mode_state;
assign o_auto = auto_state;
assign o_set  = set_state;
assign o_off_set = off_state;





always@(posedge i_clk,posedge i_reset)begin


    if(i_reset)begin

         c_state <= IDLE;
         data_reg <= 0;
         get_state <= 0;
         btn_state <= 0;
         mode_state <= 0;
		 set_state <= 0;
		 off_state <= 0;
         auto_state <=0;
         done_cnt <=0;
         handshake <=0;
         error <= 0;
		 off <= 0;

    end

    else begin
        c_state <= n_state;
        data_reg <= n_data_reg;
        get_state <= n_get_state;
        btn_state <= n_btn_state;
        mode_state <= n_mode_state;
        auto_state <= n_auto_state;
		set_state <= n_set_state;
		off_state <= n_off_state;
        done_cnt <= n_done_cnt;
        handshake <= n_handshake;
        error <= n_error;
		off <= n_off;

    end

end

always@(*)begin

       n_state    = c_state ;
       n_data_reg = data_reg ;
       n_get_state = get_state ;
       n_btn_state = btn_state ;
       n_mode_state = mode_state;
       n_auto_state = auto_state;
	   n_set_state  = set_state;
       n_done_cnt = done_cnt;
	   n_off_state = off_state; 
       n_handshake = 0;
       n_error = 0;
	   n_off = off; 
       bad = 0;
       done = 0;

       if(c_state == IDLE)begin
            n_data_reg = 0;
            n_get_state = 0;
            n_btn_state = 0;
            n_mode_state = 0;
            n_auto_state = 0;
			n_set_state  = 0;
			n_off_state = 0;
            n_done_cnt = 0;
       end

       if(w_byte)begin

        case(c_state)
        IDLE : begin
                if(i_ascii == START_CHAR)begin
                    n_state = SLASH;
                end
               end

        SLASH : begin

                 n_btn_state = 0;
                 n_get_state = 0;
                 n_mode_state =0;
                 n_auto_state = 0;
				 n_set_state = 0;
				 n_off_state = 0;

                 case(i_ascii)

                    "g" : begin
                            n_state = g;
                            n_get_state = 1;
                          end

                    "m" : begin
                            n_state = m;
                            n_mode_state = 1;
                          end
                    "b" : begin
                            n_state = b;
                            n_btn_state = 1;
                          end
                    "a" : begin
                            n_state = a;
                            n_auto_state = 1;
                          end

                    "s" : begin
                            n_state = s;
                            n_set_state = 1;
                          end
					
                    "o" : begin
                            n_state = o;
                            n_off_state = 1;
                          end

                     default : bad = 1;

                 endcase

               end


       s:  begin
            if(i_ascii == "e") n_state = e;
            else               bad = 1;
           end
	   	  

       g:  begin
            if(i_ascii == "e") n_state = e;
            else               bad = 1;
           end

       e:  begin

            if(i_ascii == "t") n_state = t;
            else               bad = 1;
           end

       t:  begin
            if(get_state)begin
                if(i_ascii == " ") n_state = SPACE;
                else               bad = 1;
            end
            else if(btn_state)begin
                if(i_ascii == "n") n_state = n;
                else               bad = 1;
            end
            else if(auto_state)begin
                if(i_ascii == "o") n_state = o;
                else               bad = 1;
            end

            else if(set_state)begin
                if(i_ascii == " ") n_state = SPACE;
                else               bad = 1;
            end

            else begin
                bad = 1;
            end
           end


       m:  begin
            if(i_ascii == "o") n_state = o;
            else               bad = 1;
           end

       o:  begin
            if(auto_state)begin
                if(i_ascii == " ") n_state = SPACE;
                else               bad = 1;
            end
            else if(mode_state)begin
                if(i_ascii == "d") n_state = d;
                else               bad = 1;
            end
	
			else if(off_state)begin

				if(i_ascii == "f")begin
				n_state = f;
				end
				else 			 bad = 1;

			end


            else begin
                bad = 1;
            end
           end


	   f:  begin
	  
	  			if(i_ascii == "f")begin
	   				if(!off) begin n_state = f; 
							   n_off = off+1;
						 	 end
					else bad = 1;
				end
				else if(i_ascii == " ") begin
							n_state = SPACE;
							n_off   = 0;
				end
				else bad = 1;
			
			end
			 
	   
       d:  begin
            if(i_ascii == " ") n_state = SPACE;
            else               bad = 1;
           end

       b:  begin
            if(i_ascii == "t") n_state = t;
            else               bad = 1;
           end

       n:  begin
            if(i_ascii == " ") n_state = SPACE;
            else               bad = 1;
           end


       a:  begin
            if(i_ascii == "u") n_state = u;
            else               bad = 1;
           end

       u:  begin
            if(i_ascii == "t") n_state = t;
            else               bad = 1;
           end


      SPACE : begin
                if(btn_state)begin
                    case(i_ascii)
                        "R", "L", "U", "D" : begin
                            n_data_reg = {data_reg[DATA_WIDTH-BIT_WIDTH-1:0], i_ascii};
                            done = 1;
                        end
                        default : bad = 1;
                    endcase
                end

                else if(auto_state||off_state)begin

                    if(i_ascii == CR || i_ascii == LF)begin
                        if(done_cnt == 0) bad = 1;
                        else              done = 1;
                    end
                    else begin
                        n_data_reg = {data_reg[DATA_WIDTH-BIT_WIDTH-1:0], i_ascii};
                        if(done_cnt == OPT_LEN-2) done = 1;
                        else                      n_done_cnt = done_cnt + 1;
                    end

                end


                else begin
                    if(i_ascii == CR || i_ascii == LF)begin
                        if(done_cnt == 0) bad = 1;
                        else              done = 1;
                    end
                    else begin
                        n_data_reg = {data_reg[DATA_WIDTH-BIT_WIDTH-1:0], i_ascii};
                        if(done_cnt == OPT_LEN-1) done = 1;
                        else                      n_done_cnt = done_cnt + 1;
                    end
                end
              end

      default : n_state = IDLE;

    endcase

       end

       if(done)begin
            n_state = IDLE;
            n_done_cnt = 0;
            n_handshake = 1;
       end

       if(bad)begin
            n_error = 1;
            n_data_reg = 0;
            n_get_state = 0;
            n_btn_state = 0;
            n_mode_state = 0;
            n_auto_state = 0;
            n_done_cnt = 0;
            n_state = (i_ascii == START_CHAR) ? SLASH : IDLE;
       end

end


endmodule
