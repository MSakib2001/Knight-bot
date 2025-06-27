`timescale 1ns/1ps
module TourCmd_tb();


// internal signal
  logic clk,rst_n;			// 50MHz clock and asynch active low reset
  logic start_tour;			// from done signal from TourLogic
  logic [15:0] cmd_UART;	// cmd from UART_wrapper
  logic [4:0] mv_indx;      // "address" to access next move
  logic cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  logic [15:0] cmd;		// multiplexed cmd to cmd_proc
  logic cmd_rdy;			// cmd_rdy signal to cmd_proc
  logic clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  logic send_resp;			// lets us know cmd_proc is done with the move command
  logic [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)
  logic [7:0] move_cmd_mem [0:7]; // Memory to store/access moves

// instantiate TourCmd module
TourCmd iTourCmd (
.clk(clk), 
.rst_n(rst_n), 
.start_tour(start_tour),			
.move(move_cmd_mem[mv_indx]),			
.mv_indx(mv_indx),	
.cmd_UART(cmd_UART),	
.cmd_rdy_UART(cmd_rdy_UART),		
.cmd(cmd),	
.cmd_rdy(cmd_rdy),			
.clr_cmd_rdy(clr_cmd_rdy),		
.send_resp(send_resp),			
.resp(resp)

);



// Task to test the states for a certain move
task test_move(input logic [15:0]vertical_cmd, input logic [15:0]horizontal_cmd);
begin
 // Currently at Move_Vertical
    if (cmd !== vertical_cmd) begin
		$error("Failed to match cmd at index %0d: Expected cmd = %0h, got  cmd = %0h",
				mv_indx, vertical_cmd, cmd);
		$stop; // Stop simulation on failure
	end


    repeat(2) @(negedge clk); // state transition
    clr_cmd_rdy = 1;
    @(negedge clk);
    clr_cmd_rdy = 0;
	
	// Currently at Wait_Vertical
	if (cmd !== vertical_cmd) begin
		$error("Failed to match cmd at index %0d: Expected cmd = %0h, got  cmd = %0h",
				mv_indx, vertical_cmd, cmd);
		$stop; // Stop simulation on failure
	end


    repeat(2) @(negedge clk);
    send_resp = 1;
    @(negedge clk);
    send_resp = 0;
	
	// Currently at Move_Horizontal
	if (cmd !== horizontal_cmd) begin
		$error("Failed to match cmd at index %0d: Expected cmd = %0h, got  cmd = %0h",
				mv_indx, horizontal_cmd, cmd);
		$stop; // Stop simulation on failure
	end

    // Move to the next state
    repeat(2) @(negedge clk);
    clr_cmd_rdy = 1;
    @(negedge clk);
    clr_cmd_rdy = 0;
	
	// Currently at Wait_Horizontal
	if (cmd !== horizontal_cmd) begin
	$error("Failed to match cmd at index %0d: Expected cmd = %0h, got  cmd = %0h",
			mv_indx, horizontal_cmd, cmd);
	$stop; // Stop simulation on failure
	end

    @(negedge clk);
	send_resp = 1;
    @(negedge clk);
    send_resp = 0;
end
endtask


initial begin
 // Initial values
    start_tour = 0;
    cmd_UART = 16'h0000;
    cmd_rdy_UART = 0;
    clr_cmd_rdy = 0;
    send_resp = 0;
	// initialize move memory
	move_cmd_mem[0] = 8'b00000001; 
    move_cmd_mem[1] = 8'b00000010;
    move_cmd_mem[2] = 8'b00000100;
    move_cmd_mem[3] = 8'b00001000;
    move_cmd_mem[4] = 8'b00010000;
    move_cmd_mem[5] = 8'b00100000;
    move_cmd_mem[6] = 8'b01000000;
    move_cmd_mem[7] = 8'b10000000;

    // apply reset 
	@(negedge clk)
	rst_n = 1'b0;
	repeat(2) @(posedge clk)
	rst_n = 1'b1;

    // Start the tour
    @(negedge clk)
	start_tour = 1;
    @(negedge clk);
    start_tour = 0;
	
	
	// Passing in the expected vertical and horizontal move cmd according to index
	
	// Move_index = 0
	
	test_move(16'h4002, 16'h4BF1);
		
	// Move_index = 1
	
	test_move(16'h4002, 16'h43F1);
	
	// Move_index = 2
	
	test_move(16'h43F2, 16'h4001);
	
	
	// If no errors so far, then all tests passed
	$display("YAHOO all tests pass!");

    // End simulation
    repeat(2) @(posedge clk);
    $stop;

end


// Clock generation
initial begin
	clk = 0;
	forever #5 clk = ~clk; // 100 MHz clock (period of 10 time units)
end

endmodule
	  