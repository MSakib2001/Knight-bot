
module KnightsTour_SOLVE_tb();

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
    

    task rst_dut();
        repeat(3)@(negedge clk)
            RST_n = 0;
        @(negedge clk)
            RST_n = 1;
    endtask

    // continues execution if sig goes high before timeout
    // otherwise it gives an error message and stops the simulation
    //also this actually waits for POSEDGE not high
    task automatic wait_for_posedge(ref sig);
        fork
            begin: timeout
                repeat(TIMEOUT) @(posedge clk);
                $display("ERR: timed out on test %d", TEST_NUM);
                $stop();
            end
            begin
                //disables timeout error if sig goes high
                @(posedge sig)
                    disable timeout;
            end
        join
    endtask

    //TODO not entirely sure what positive acknowledge is
    //checks for a positive acknowledgement
    task automatic chk_pos_awk();
        //resp of 0xA5 (done with move) or 0x5A (in progress)
        wait_for_posedge(resp_rdy);
        assert(resp === 8'hA5) else begin                                         
            $display("ERR on test %d: got %d expected %d", TEST_NUM, resp, 8'hA5);
            #1 $stop();                                                             
        end                                                                         
    endtask

    //sends cmd using remotecomm to proc
    task remote_send_cmd(input [15:0] cmd_to_send);
        @(negedge clk) begin
            cmd = cmd_to_send;
            send_cmd = 1;
        end

        @(negedge clk) begin
            send_cmd = 0;
        end
    endtask

    //checks if the robot is in the middle of a square on the grid and outputs its x and y
    task in_mid_rail(output is_centered, output [2:0] x, y);

        if (iPHYS.xx[11:8] >= 4'h6 && iPHYS.xx[11:8] <= 4'ha)
            is_centered = 1;
        else 
            is_centered = 0;

        x = iPHYS.xx[14:12];
        y = iPHYS.yy[14:12];

    endtask;
    
    logic knight_centered;
    logic [2:0] knight_x, knight_y;

    initial begin
        clk = 0;
        cmd = 0;
        send_cmd = 0;


        repeat(4)@(posedge clk);
        rst_dut();
        //initialization tests

        in_mid_rail(knight_centered, knight_x, knight_y);

        //check if knight is centered
        TEST_NUM = 0; 

        assert(knight_centered === 1'b1) else begin                                         
            $display("ERR on test %d: got %d expected %d", TEST_NUM, knight_centered, 1'b1);
            #1 $stop();                                                             
        end                                                                         

        //check if knight is in the correct position
        //also a sanity check to see if our in_mid_rail task is correct
        TEST_NUM = 1; 
        assert(knight_x === 2) else begin                                         
            $display("ERR on test %d: got %d expected %d", TEST_NUM, knight_x, 1);
            #1 $stop();                                                             
        end        


        TEST_NUM = 2; 
        assert(knight_y === 2) else begin                                         
            $display("ERR on test %d: got %d expected %d", TEST_NUM, knight_y, 2);
            #1 $stop();                                                             
        end        

        //verify that the robot is currently in a square and at the square defined in the phys: 2, 2
        

        //see if pwms are working by waiting for an edge
        
        TEST_NUM = 3;
        wait_for_posedge(lftPWM1);
        
        TEST_NUM = 4;
        wait_for_posedge(lftPWM2);
        
        TEST_NUM = 5;
        wait_for_posedge(rghtPWM1);
        
        TEST_NUM = 6;
        wait_for_posedge(rghtPWM2);
        


        //needs fork and join because KnightPhysics.iNemo.Nemosetup cant be referenced
        TEST_NUM = 7;

        fork
            begin: timeout
                repeat(TIMEOUT) @(posedge clk);
                $strobe("ERROR test %d: NEMO_setup not asserted (timeout)", TEST_NUM);
                #1 $stop();
            end
            begin
                
                
                @(posedge iPHYS.iNEMO.NEMO_setup)  begin
                    disable timeout;
                end
            end
        join

        

        TEST_NUM = 8;
        //send command to calibrate it
        //opcode == 4'b0010
        remote_send_cmd(16'h2000);
        
        chk_pos_awk();
        //for an awk I think cal_done->snd_resp->uart transmission back

        //don't know whether caldone is the awk or the resp is
        TEST_NUM = 9;

        remote_send_cmd(16'h6022);

    end
    
    always @(posedge iDUT.iTL.update_position) begin
        integer y;
	    for (y=4; y>=0; y--) begin
	        $display("%2d  %2d  %2d  %2d  %2d\n",iDUT.iTL.board[0][y],iDUT.iTL.board[1][y],
	    	         iDUT.iTL.board[2][y],iDUT.iTL.board[3][y],iDUT.iTL.board[4][y]);
	    end
	    $display("--------------------\n");
    end


    always
        #5 clk = ~clk;
  
endmodule


