module P_term( input [11:0]error, output signed[13:0] P_term);


logic signed [9:0] err_sat;
localparam P_COEFF = 6'h10;

// Saturating
assign err_sat = (error[11] & (~&error[10:9])) ?  10'h200 :  // most negative
                 (~error[11] & |error[10:9])   ?  10'h1FF :  // most positive
				 error[9:0];
				 
				
assign P_term = err_sat * $signed(P_COEFF);  

  
endmodule
	  