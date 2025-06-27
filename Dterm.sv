module Dterm(input signed [9:0] err_sat, input clk, input rst_n, input err_vld, output signed [12:0] D_term);
	
	logic signed [9:0] First_FF_out, Second_FF_out, prev_err;
	logic signed [9:0] D_diff;
	logic signed [7:0] D_diff_sat;
	
	localparam D_COEFF = 5'h07;
	
	// If err_vld is asserted pipeline FFs get new value, otherwise retains current value
	// First pipeline FF
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			First_FF_out <= 10'h000;
		else if (err_vld)
			First_FF_out <= err_sat;
		
	// Second pipeline FF		
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			Second_FF_out <= 10'h000;
		else if (err_vld)
			Second_FF_out <= First_FF_out;
		
	// Third pipeline FF	
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			prev_err <= 10'h000;
		else if (err_vld)
			prev_err <= Second_FF_out;
		
	
	// Calculating difference between current and previous error
	assign D_diff = err_sat - prev_err;
	
	// max positive value we can represent in 8 bits is 0x7F
	// max negative value we can represent in 8 bits is 0x80
	// Saturate 10 bit D_diff to 8 bit
	assign D_diff_sat = (~D_diff[9] & |D_diff[8:7]) ? 8'h7F :
						(D_diff[9] & ~&D_diff[8:7]) ? 8'h80 :
						D_diff[7:0];
	
    // Calculate D_term = saturated D_diff * 5'h07	
	assign D_term = D_diff_sat * $signed(D_COEFF); // casting D_COEFF to signed as this is a signed multiplication
	

endmodule