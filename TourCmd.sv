module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
			   clr_cmd_rdy,send_resp,resp);

  input clk,rst_n;			// 50MHz clock and asynch active low reset
  input start_tour;			// from done signal from TourLogic
  input [7:0] move;			// encoded 1-hot move to perform
  output reg [4:0] mv_indx;	// "address" to access next move
  input [15:0] cmd_UART;	// cmd from UART_wrapper
  input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  output [15:0] cmd;		// multiplexed cmd to cmd_proc
  output cmd_rdy;			// cmd_rdy signal to cmd_proc
  input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  input send_resp;			// lets us know cmd_proc is done with the move command
  output [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)
  
// internal signals 
  logic mux_sel, cmd_rdy_from_tour, mv_indx_en, mv_indx_clr;
  logic signed [15:0] cmd_from_tour, vertical_move_cmd, horizontal_move_cmd;

// mv_indx counter
always @(posedge clk, negedge rst_n)begin
	if (!rst_n)
		mv_indx <= 5'h0;
	else if(mv_indx_clr)
		mv_indx <= 5'h0;
	else if(mv_indx_en)
		mv_indx <= mv_indx + 1;
end	

// cmd and cmd_rdy muxes
assign cmd = mux_sel ? cmd_from_tour : cmd_UART;
assign cmd_rdy = mux_sel ? cmd_rdy_from_tour : cmd_rdy_UART;

// resp logic cmd is from uart OR last move
assign resp = (cmd == cmd_UART) | (mv_indx == 5'd23) ? 8'hA5 : 8'h5A;

// move decompose
always_comb begin
	case (move)
    8'b00000001: begin 
		vertical_move_cmd = 16'h4002; // Bit 0 is set
		horizontal_move_cmd = 16'h5BF1;
	end
    8'b00000010: begin
		vertical_move_cmd = 16'h4002; // Bit 1 is set
		horizontal_move_cmd = 16'h53F1;
	end
    8'b00000100: begin
		vertical_move_cmd = 16'h4001; // Bit 2 is set
		horizontal_move_cmd = 16'h53F2;
	end
    8'b00001000: begin
		vertical_move_cmd = 16'h47F1; // Bit 3 is set
		horizontal_move_cmd = 16'h53F2;
	end
    8'b00010000: begin
		vertical_move_cmd = 16'h47F2; // Bit 4 is set
		horizontal_move_cmd = 16'h53F1;
	end
    8'b00100000: begin
		vertical_move_cmd = 16'h47F2; // Bit 5 is set
		horizontal_move_cmd = 16'h5BF1;
	end
    8'b01000000: begin
		vertical_move_cmd = 16'h47F1; // Bit 6 is set
		horizontal_move_cmd = 16'h5BF2;
	end
    8'b10000000: begin
		vertical_move_cmd = 16'h4001; // Bit 7 is set
		horizontal_move_cmd = 16'h5BF2;
	end
    default: begin
		vertical_move_cmd = 16'h0000;    // Invalid  
		horizontal_move_cmd = 16'h0000;
	end
endcase


end

// state machine
typedef enum reg [2:0] {IDLE, Move_Vertical, Wait_Vertical, Move_Horizontal, Wait_Horizontal} state_t;

state_t state, nxt_state;

// infer state flops
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end
always_comb begin
	// default outputs
    mux_sel = 1'b1;
	mv_indx_clr = 1'b0;
	mv_indx_en = 1'b0;
	cmd_rdy_from_tour = 1'b0;
	cmd_from_tour = 16'h0000;
	// default state
	nxt_state = state;
	
	case (state)
		IDLE : begin
				mux_sel = 1'b0;
				if (start_tour) begin
					mv_indx_clr = 1'b1;
					mux_sel = 1'b1;
					nxt_state = Move_Vertical;
				end
			end
			
		Move_Vertical : begin
				cmd_from_tour = vertical_move_cmd; 
				cmd_rdy_from_tour = 1'b1;
				if (clr_cmd_rdy) begin
					
					nxt_state = Wait_Vertical;
				end
			end	
				
		Wait_Vertical :  begin
				cmd_from_tour = vertical_move_cmd; 
				if (send_resp) begin
					nxt_state = Move_Horizontal;
				end
			end	
		
		Move_Horizontal :  begin
				cmd_from_tour = horizontal_move_cmd; 
				cmd_rdy_from_tour = 1'b1;
				if (clr_cmd_rdy) begin
					
					nxt_state = Wait_Horizontal;
				end
			end	
   
        Wait_Horizontal :  begin
				cmd_from_tour = horizontal_move_cmd; 
				if (send_resp & (mv_indx !== 5'd23)) begin
					mv_indx_en = 1'b1;
					nxt_state = Move_Vertical;
				end
				else if (send_resp & (mv_indx == 5'd23)) begin
					nxt_state = IDLE;
				end
			end	  
			
			
		default : nxt_state = IDLE;
	endcase
end 
  
endmodule