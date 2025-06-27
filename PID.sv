module PID( 
input  clk, rst_n, moving, err_vld,
input [11:0]error,
input [9:0]frwrd,
output [10:0] lft_spd, rght_spd

);

// Inputs pipeline flops
logic signed [9:0]  err_sat_stage2,  err_sat_stage3;
logic err_vld_stage1, err_vld_stage2, err_vld_stage3, err_vld_stage4;
logic moving_stage1, moving_stage2, moving_stage3, moving_stage4;
logic [9:0]  frwrd_stage2, frwrd_stage3, frwrd_stage4;
logic signed [9:0] err_sat;
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin

        err_sat_stage2 <= 10'h000;
        err_sat_stage3 <= 10'h000;
		
        err_vld_stage2 <= 1'b0;
        err_vld_stage3 <= 1'b0;

        moving_stage2 <= 1'b0;
        moving_stage3 <= 1'b0;
        moving_stage4 <= 1'b0;

        frwrd_stage2 <= 10'h000;
        frwrd_stage3 <= 10'h000;
        frwrd_stage4 <= 10'h000;
    end else begin
        err_sat_stage2 <=  err_sat;
        err_sat_stage3 <= err_sat_stage2;
		
		err_vld_stage2 <= err_vld;
        err_vld_stage3 <= err_vld_stage2;

        moving_stage2 <= moving;
        moving_stage3 <= moving_stage2;
        moving_stage4 <= moving_stage3;
		
		frwrd_stage2 <= frwrd;
        frwrd_stage3 <= frwrd_stage2;
        frwrd_stage4 <= frwrd_stage3;
    end
end

/////////////// Stage 1 ////////////////////

///////// P term /////////////////////////
//logic signed [9:0] err_sat;
logic signed[13:0] P_term;
localparam P_COEFF = 6'h10;

// Saturating
assign err_sat = (error[11] & (~&error[10:9])) ?  10'h200 :  // most negative
                 (~error[11] & |error[10:9])   ?  10'h1FF :  // most positive
				 error[9:0];
				 
				
assign P_term = err_sat * $signed(P_COEFF);  

///////////////////////////////////////////// 
//P-term pipeline flop
logic signed [13:0] P_term_stage2, P_term_stage3, P_term_stage4;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        P_term_stage2 <= 14'h0000;
        P_term_stage3 <= 14'h0000;
        P_term_stage4 <= 14'h0000;
    end else begin
        P_term_stage2 <= P_term;           // Pass from stage 1 to stage 2
        P_term_stage3 <= P_term_stage2;    // Pass from stage 2 to stage 3
        P_term_stage4 <= P_term_stage3;    // Pass from stage 3 to stage 4
    end
end

/////////////// Stage 2 ////////////////////

///////// I term /////////////////////////
logic [14:0]err_sat_ext, sum, mux_out_1, nxt_integrator, integrator;
logic ov,  and_result;
logic [8:0] I_term;
// Adder logic
assign sum = err_sat_ext + integrator;

// Sign extending err_sat
assign err_sat_ext = {{5{err_sat_stage2[9]}},err_sat_stage2};

// Muxes
assign mux_out_1 = and_result ? sum : integrator;
assign nxt_integrator = moving_stage2 ? mux_out_1 : 15'h0000;

// Overflow logic
assign ov = (err_sat_ext[14] ^ integrator[14]) ? 1'b0 : (integrator[14] ^ sum[14]) ? 1'b1: 1'b0;                                                        
assign and_result = err_vld_stage2 & (~ov);

always_ff@(posedge clk, negedge rst_n) begin
 if(!rst_n)
  integrator <= 15'h0000;
 else
  integrator <= nxt_integrator;
end

assign I_term = integrator[14:6];

///////////////////////////////////////////// 
// I-term pipeline flop
logic signed [8:0] I_term_stage3, I_term_stage4;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        I_term_stage3 <= 9'h000;
        I_term_stage4 <= 9'h000;
    end else begin
        I_term_stage3 <= I_term;           // Pass from stage 2 to stage 3
        I_term_stage4 <= I_term_stage3;    // Pass from stage 3 to stage 4
    end
end
/////////////// Stage 3 ////////////////////

///////// D term /////////////////////////
logic signed [9:0] First_FF_out, Second_FF_out, prev_err;
logic signed [9:0] D_diff;
logic signed [7:0] D_diff_sat;
logic signed [12:0] D_term;
	
localparam D_COEFF = 5'h07;
	
	// If err_vld is asserted pipeline FFs get new value, otherwise retains current value
	// First pipeline FF
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			First_FF_out <= 10'h000;
		else if (err_vld_stage3)
			First_FF_out <= err_sat_stage3;
		
	// Second pipeline FF		
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			Second_FF_out <= 10'h000;
		else if (err_vld_stage3)
			Second_FF_out <= First_FF_out;
		
	// Third pipeline FF	
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			prev_err <= 10'h000;
		else if (err_vld_stage3)
			prev_err <= Second_FF_out;
		
	
	// Calculating difference between current and previous error
	assign D_diff = err_sat_stage3 - prev_err;
	
	// max positive value we can represent in 8 bits is 0x7F
	// max negative value we can represent in 8 bits is 0x80
	// Saturate 10 bit D_diff to 8 bit
	assign D_diff_sat = (~D_diff[9] & |D_diff[8:7]) ? 8'h7F :
						(D_diff[9] & ~&D_diff[8:7]) ? 8'h80 :
						D_diff[7:0];
	
    // Calculate D_term = saturated D_diff * 5'h07	
	assign D_term = D_diff_sat * $signed(D_COEFF); // casting D_COEFF to signed as this is a signed multiplication
	
///////////////////////////////////////////// 
// D-term pipeline flop
logic signed [12:0] D_term_stage4;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        D_term_stage4 <= 13'h0000;
    end else begin
        D_term_stage4 <= D_term;           // Pass from stage 3 to stage 4
    end
end

/////////////// Stage 4 ////////////////////

// PID block
logic [13:0] PID, P_term_sign_ext, I_term_sign_ext, D_term_sign_ext;
logic [12:0] P_term_divide;
logic [10:0] frwrd_zero_ext;
logic [10:0]lft_spd_mux_out, rght_spd_mux_out;

// preparing P, I and D terms for PID calculation (14 bits)
assign P_term_divide = P_term_stage4 / 2;       // Divide P term by 2
assign P_term_sign_ext = P_term_divide[12] ? {1'b1,P_term_divide} : {1'b0,P_term_divide};     // sign extend 1/2 (P term)
assign I_term_sign_ext = I_term_stage4[8] ? {5'b11111,I_term_stage4} : {5'b00000,I_term_stage4};                  // sign extend I term
assign D_term_sign_ext = D_term_stage4[12] ? {1'b1,D_term_stage4} : {1'b0,D_term_stage4};                         // sign extend D term

// calculate PID
assign PID = P_term_sign_ext + I_term_sign_ext + D_term_sign_ext;

// zero extend frwrd value to 11 bits
assign frwrd_zero_ext = {1'b0, frwrd_stage4};

// Muxes to check if robot is moving or not and calculate motor speeds
assign lft_spd_mux_out = moving_stage4 ? (frwrd_zero_ext + PID[13:3]) : 11'h000;
assign rght_spd_mux_out = moving_stage4 ? (frwrd_zero_ext - PID[13:3]) : 11'h000;

// Saturation check and final assign
assign lft_spd = lft_spd_mux_out[10] & (~PID[13])? 11'h3FF : lft_spd_mux_out;    // positive saturation only possible if PID is postive but the sum is negative
assign rght_spd = rght_spd_mux_out[10] & (PID[13])? 11'h3FF : rght_spd_mux_out;   // positive saturation only possible if PID is negative and the sum is negative



endmodule
	  