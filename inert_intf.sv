//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.      //
// In this application, we only use the Z-axis    //
// gyro for determining the heading of the robot. //
// Fusion correction comes from "guardrail"       //
// signals lftIR/rghtIR.                          //
////////////////////////////////////////////////////
module inert_intf(clk, rst_n, strt_cal, cal_done, heading, rdy, lftIR,
                  rghtIR, SS_n, SCLK, MOSI, MISO, INT, moving);

  parameter FAST_SIM = 1; // Used to speed up simulation
  
  // Input ports
  input clk, rst_n;          // Clock and active-low reset
  input MISO;                // SPI input from inertial sensor
  input INT;                 // Interrupt signal from the sensor
  input strt_cal;            // Start calibration signal
  input moving;              // Indicates if the robot is moving
  input lftIR, rghtIR;       // Guardrail correction signals
  
  // Output ports
  output cal_done;           // Pulses high for 1 clock when calibration is done
  output signed [11:0] heading; // Heading of the robot (0 = origin, 3FF = 90° CCW, 7FF = 180° CCW)
  output rdy;                // Pulses high for 1 clock when new data is ready
  output SS_n, SCLK, MOSI;   // SPI control signals

  //////////////////////////////////
  // Internal signal declarations //
  //////////////////////////////////
  logic vld;                  // Valid signal for angular rate readings
  logic snd, done;            // SPI command send and completion signals
  logic set_vld, timer_en;    // Flags to set valid signal and enable timer
  logic C_Y_H, C_Y_L;         // Flags to capture yaw high and low bytes
  logic INT_Signle_Flopped, INT_Double_Flopped; // Flopped versions of INT signal
  logic [15:0] cmd, resp;     // SPI command and response registers
  logic [15:0] yaw_rt;        // Combined yaw rate register (high and low)
  logic [7:0] yaw_rt_L, yaw_rt_H; // Low and high bytes of yaw rate
  logic [15:0] timer;         // Timer for delays
  
  /////////////////////////////////////////////////
  // Double-flop INT signal for synchronization //
  /////////////////////////////////////////////////
  always @(posedge clk) begin
    if (!rst_n) begin
      INT_Signle_Flopped <= 1'b0; // Reset INT first flop
      INT_Double_Flopped <= 1'b0; // Reset INT second flop
    end else begin
      INT_Signle_Flopped <= INT; // First stage of synchronization
      INT_Double_Flopped <= INT_Signle_Flopped; // Second stage of synchronization
    end
  end	

  ///////////////////////////////////////////
  // Timer to introduce delay in commands //
  ///////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      timer <= 16'h0000;         // Reset timer
    else if (timer_en)
      timer <= timer + 1;        // Increment timer when enabled
  end	

  ///////////////////////////////////////////
  // State machine for sensor interaction //
  ///////////////////////////////////////////
  typedef enum reg [2:0] {INIT1, INIT2, INIT3, IDLE, Read_yawL, Read_yawH} state_t;

  state_t state, nxt_state;

  // State machine: Sequential logic
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= INIT1; // Start in INIT1 state on reset
    else
      state <= nxt_state; // Transition to the next state
  end

  // State machine: Combinational logic
  always_comb begin
    // Default outputs
    snd = 0;            // Do not send SPI command by default
    C_Y_L = 0;          // Do not capture yaw low byte by default
    C_Y_H = 0;          // Do not capture yaw high byte by default
    set_vld = 0;        // Do not set valid signal by default
    timer_en = 0;       // Timer is disabled by default
    cmd = 16'h0000;     // Default command value
    nxt_state = state;  // Default next state is the current state
    
    case (state)
      INIT1: begin
        cmd = 16'h0d02;         // Initialization command 1
        timer_en = 1;           // Enable timer
        if (&timer) begin       // Wait until timer overflows
          snd = 1;              // Send SPI command
          nxt_state = INIT2;    // Move to INIT2 state
        end
      end

      INIT2: begin
        cmd = 16'h1160;         // Initialization command 2
        if (done) begin         // Wait for SPI transaction to complete
          snd = 1;              // Send next SPI command
          nxt_state = INIT3;    // Move to INIT3 state
        end
      end	

      INIT3: begin
        cmd = 16'h1440;         // Initialization command 3
        if (done) begin         // Wait for SPI transaction to complete
          snd = 1;              // Send final initialization command
          nxt_state = IDLE;     // Move to IDLE state
        end
      end	

      IDLE: begin
        cmd = 16'ha6xx;         // Read yaw low byte command
        if (INT_Double_Flopped) begin // Wait for interrupt signal
          snd = 1;              // Send SPI command
          nxt_state = Read_yawL; // Move to Read_yawL state
        end
      end	

      Read_yawL: begin
        cmd = 16'ha7xx;         // Read yaw high byte command
        if (done) begin         // Wait for SPI transaction to complete
          snd = 1;              // Send next SPI command
          C_Y_L = 1;            // Capture yaw low byte
          nxt_state = Read_yawH; // Move to Read_yawH state
        end
      end	

      Read_yawH: begin
        if (done) begin         // Wait for SPI transaction to complete
          set_vld = 1;          // Set valid signal
          C_Y_H = 1;            // Capture yaw high byte
          nxt_state = IDLE;     // Return to IDLE state
        end
      end	

      default: nxt_state = INIT1; // Default to INIT1 on invalid state
    endcase
  end 

  //////////////////////////////////////
  // Flop vld signal for valid yaw rate //
  //////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      vld <= 1'b0;         // Reset valid signal
    else if (set_vld)
      vld <= 1'b1;         // Set valid signal when set_vld is high
    else
      vld <= 1'b0;         // Clear valid signal
  end
	
  //////////////////////////////////
  // Holding registers for yaw rate //
  /////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      yaw_rt_L <= 8'h00;    // Reset yaw low byte
      yaw_rt_H <= 8'h00;    // Reset yaw high byte
    end else if (C_Y_L)
      yaw_rt_L <= resp[7:0]; // Capture yaw low byte
    else if (C_Y_H)
      yaw_rt_H <= resp[7:0]; // Capture yaw high byte
  end

  assign yaw_rt = {yaw_rt_H, yaw_rt_L}; // Combine high and low bytes into yaw rate

  ///////////////////////////////////////////////
  // Instantiate SPI monarch for SPI interface //
  ///////////////////////////////////////////////
  SPI_mnrch spi_mnrch(
    .clk(clk), .rst_n(rst_n), .snd(snd), .cmd(cmd),
    .MISO(MISO), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI),
    .done(done), .resp(resp)
  );

  //////////////////////////////////////////////////////
  // Instantiate inertial integrator to calculate heading //
  //////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(
    .clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .vld(vld),
    .rdy(rdy), .cal_done(cal_done), .yaw_rt(yaw_rt), .moving(moving),
    .lftIR(lftIR), .rghtIR(rghtIR), .heading(heading)
  );

endmodule
