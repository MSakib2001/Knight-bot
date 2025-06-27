module I_term( input [9:0]error_sat, input clk,rst_n,moving,err_vld, output [8:0] I_term);

logic [14:0]err_sat_ext, sum, mux_out_1, nxt_integrator, integrator;
logic ov,  and_result;

// Adder logic
assign sum = err_sat_ext + integrator;

// Sign extending err_sat
assign err_sat_ext = {{5{error_sat[9]}},error_sat};

// Muxes
assign mux_out_1 = and_result ? sum : integrator;
assign nxt_integrator = moving ? mux_out_1 : 15'h0000;

// Overflow logic
assign ov = (err_sat_ext[14] ^ integrator[14]) ? 1'b0 : (integrator[14] ^ sum[14]) ? 1'b1: 1'b0;                                                        
assign and_result = err_vld & (~ov);

always_ff@(posedge clk, negedge rst_n) begin
 if(!rst_n)
  integrator <= 15'h0000;
 else
  integrator <= nxt_integrator;
end

assign I_term = integrator[14:6];


  
endmodule
	  