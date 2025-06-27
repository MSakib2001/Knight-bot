module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
                frwrd,moving,tour_go,fanfare_go);

  parameter FAST_SIM = 1;      // Speeds up incrementing of frwrd register for faster simulation

  // Inputs
  input clk, rst_n;            // 50 MHz clock and asynchronous active-low reset
  input [15:0] cmd;            // Command from BLE (Bluetooth)
  input cmd_rdy;               // Command ready signal
  input cal_done;              // Calibration completion signal
  input signed [11:0] heading; // Heading from gyro
  input heading_rdy;           // Pulses high for 1 clock when heading reading is valid
  input lftIR;                 // Left IR sensor input (nudge error +)
  input cntrIR;                // Center IR sensor input (indicates passing a line)
  input rghtIR;                // Right IR sensor input (nudge error -)

  // Outputs
  output logic clr_cmd_rdy;    // Mark command as consumed
  output logic send_resp;      // Command finished, send response via UART/BT
  output logic strt_cal;       // Initiate calibration of gyro
  output reg signed [11:0] error; // Error signal to PID (heading - desired_heading)
  output reg [9:0] frwrd;      // Forward speed register
  output logic moving;         // Asserted when moving (enables yaw integration)
  output logic tour_go;        // Pulse to initiate TourCmd block
  output logic fanfare_go;     // Initiates "Charge!" fanfare on piezo

  // Internal signals
  logic is_fanfare_cmd, move_cmd, clr_frwrd, inc_frwrd, dec_frwrd, move_done, max_spd, cntrIR_flopped, zero;
  logic [3:0] opcode, num_square_moved, desired_num_square_moved;
  logic [11:0] desired_heading, ext_cmd_heading, err_nudge;
  logic [9:0] inc_dec_amount;

  // Decode opcode from command
  assign opcode = cmd[15:12];           // Extract the opcode from the command
  assign is_fanfare_cmd = cmd[12];      // Check if the command is a fanfare command

  // State machine for command processing
  typedef enum reg [2:0] {IDLE, Move, Calibrate, Forward_INC, Forward_DEC} state_t;

  state_t state, nxt_state;

  // State machine: Sequential logic
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= IDLE; // Start in IDLE state on reset
    else
      state <= nxt_state; // Transition to the next state
  end

  logic [11:0] abs_error;
  assign abs_error = (error[11]) ? ~error + 1 : error;

  // State machine: Combinational logic
  always_comb begin
    // Default outputs
    clr_cmd_rdy = 0;
    move_cmd = 0;
    send_resp = 0;     
    clr_frwrd = 0;          
    inc_frwrd = 0;           
    dec_frwrd = 0;          
    fanfare_go = 0;       
    moving = 0;      
    strt_cal = 0;     
    tour_go = 0;           
    nxt_state = state;       

    // State machine logic
    case (state)
      IDLE: begin
        // Check for various commands
        if (cmd_rdy & (opcode == 4'b0010)) begin
          strt_cal = 1'b1;          // Start calibration
          nxt_state = Calibrate;   // Transition to Calibrate state
          clr_cmd_rdy = 1'b1;      // Clear command ready signal
        end else if (cmd_rdy & (opcode == 4'b0100 | opcode == 4'b0101)) begin
          nxt_state = Move;        // Transition to Move state
          clr_cmd_rdy = 1'b1;      // Clear command ready signal
          move_cmd = 1'b1;         // Mark as a move command
        end else if (cmd_rdy & (opcode == 4'b0110)) begin
          nxt_state = IDLE;        // Stay in IDLE state
          clr_cmd_rdy = 1'b1;      // Clear command ready signal
          tour_go = 1'b1;          // Start tour
        end
      end

      Calibrate: begin
        if (cal_done) begin
          send_resp = 1'b1;        // Send response when calibration is done
          nxt_state = IDLE;        // Return to IDLE state
        end
      end	

      Move: begin
        moving = 1'b1;             // Indicate movement
        clr_frwrd = 1'b1;          // Clear forward register
        //if (error < $signed(12'h02C) | error < $signed(12'hFD4)) begin
        if (abs_error < 12'h02C) begin
          nxt_state = Forward_INC; // Transition to Forward_INC state
        end
      end	

      Forward_INC: begin
        moving = 1'b1;             // Indicate movement
        inc_frwrd = 1'b1;          // Increment forward register
        if (move_done) begin
          nxt_state = Forward_DEC; // Transition to Forward_DEC state if move is done
        end
      end	

      Forward_DEC: begin
        moving = 1'b1;             // Indicate movement
        dec_frwrd = 1'b1;          // Decrement forward register
        if (zero) begin            // Check if forward register is zero
          if (is_fanfare_cmd) begin
            fanfare_go = 1'b1;     // Start fanfare if commanded
          end
          send_resp = 1'b1;        // Send response
          nxt_state = IDLE;        // Return to IDLE state
        end
      end	  

      default: nxt_state = IDLE;   // Default to IDLE state
    endcase
  end 

  // Increment/decrement amount based on simulation mode
  assign inc_dec_amount = FAST_SIM ? (dec_frwrd ? {9'h20,1'b0} : 10'h20) : 
                                     (dec_frwrd ? {9'h03,1'b0} : 10'h03);

  // Check for maximum forward speed
  assign max_spd = &frwrd[9:8]; // Maximum speed when top two bits are set

  // Forward register management
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      frwrd <= 10'h000;           // Reset forward register
    else if (clr_frwrd)
      frwrd <= 10'h000;           // Clear forward register
    else if (heading_rdy & inc_frwrd & ~max_spd)
      frwrd <= frwrd + inc_dec_amount; // Increment forward register
    else if (heading_rdy & dec_frwrd & ~zero)
      frwrd <= frwrd - inc_dec_amount; // Decrement forward register
  end

  // Check if forward register is zero
  assign zero = frwrd == 10'h000;

  // Center IR edge detection flop
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      cntrIR_flopped <= 1'h0;    // Reset flop
    else
      cntrIR_flopped <= cntrIR; // Capture current center IR value
  end

  // Count number of squares moved
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      desired_num_square_moved <= 4'h0; // Reset desired square count
      num_square_moved <= 4'h0;        // Reset current square count
    end else if (move_cmd) begin
      num_square_moved <= 4'h0;        // Clear current square count on move command
      desired_num_square_moved <= cmd[3:0]; // Load desired square count from command
    end else if (cntrIR & ~cntrIR_flopped) // Increment on rising edge of center IR
      num_square_moved <= num_square_moved + 4'h1;
  end

  // Check if the movement is complete
  assign move_done = ({desired_num_square_moved, 1'b0} == num_square_moved);

  // Extract heading from command
  assign ext_cmd_heading = (cmd[11:4] == 8'h00) ? 12'h000 : {cmd[11:4], 4'hF};

  // PID desired heading register
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      desired_heading <= 12'h00; // Reset desired heading
    else if (move_cmd)
      desired_heading <= ext_cmd_heading; // Load desired heading on move command
  end

  // Error signal computation
  assign err_nudge = FAST_SIM ? (lftIR ? 12'h1FF : rghtIR ? 12'hE00 : 12'h000) : 
                                (lftIR ? 12'h05F : rghtIR ? 12'hFA1 : 12'h000);

  assign error = heading - desired_heading + err_nudge; // Calculate error signal

endmodule
