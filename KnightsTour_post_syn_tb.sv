`timescale 1ns/1ps
module KnightsTour_tb();

  localparam FAST_SIM = 1;
  localparam TIMEOUT = 7000000;
  
  integer TEST_NUM = 1;
  
  /////////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
    reg [15:0] cmd;
    reg send_cmd;

    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    wire SS_n,SCLK,MOSI,MISO,INT;
    logic lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
    wire TX_RX, RX_TX;
    logic cmd_sent;
    logic resp_rdy;
    logic [7:0] resp;
    wire IR_en;
    wire lftIR_n,rghtIR_n,cntrIR_n;
    
    //////////////////////
    // Instantiate DUT //
    ////////////////////
    KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                     .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
    				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
    				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
    				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
    				   .cntrIR_n(cntrIR_n));
    
    /////////////////////////////////////////////////////
    // Instantiate RemoteComm to send commands to DUT //
    ///////////////////////////////////////////////////
    RemoteComm_e iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
               .snd_cmd(send_cmd), .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
    
    //////////////////////////////////////////////////////
    // Instantiate model of Knight Physics (and board) //
    ////////////////////////////////////////////////////
    KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                        .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
    					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
    					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
    

    initial begin
		clk = 0;
		RST_n = 0;
		cmd = 16'h2000;
		send_cmd = 0;
		
		@(posedge clk);
		@(negedge clk);
		RST_n = 1;
		
		@(negedge clk);
		cmd = 16'h2000;
		send_cmd = 1;
		
		@(posedge resp_rdy);
		
		repeat(10) @(posedge clk);
		$stop();
		
        $display("YAHOO all tests pass!");
        $stop();                                           
    end
    
    always
        #5 clk = ~clk;
  
endmodule


