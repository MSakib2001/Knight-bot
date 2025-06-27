module UART_rx(
    input clk,                  // Clock input signal
    input rst_n,                // Asynchronous active-low reset signal
    input RX,                   // Serial data input line
    input clr_rdy,              // Clear ready signal (used to clear the ready flag)
    output rdy,                 // Ready signal indicating valid data is received
    output logic [7:0] rx_data  // Received 8-bit parallel data
);

    // Internal control signals
    logic start;                // Signal to start receiving data
    logic shift;                // Signal to shift data into the shift register
    logic receiving;            // Signal indicating the UART is receiving data
    logic set_rdy;              // Signal to set the `rdy` flag
    logic done;                 // Signal indicating the reception of one frame is complete
    logic rdy_reg;              // Register to hold the ready signal

    // Baud rate and counter
    logic [11:0] baud_cnt;      // Counter for baud rate timing
    logic [11:0] baud_rate;     // Current baud rate count
    logic [3:0] bit_cnt;        // Counter for tracking received bits

    // Shift register for received data
    logic [8:0] rx_shft_reg;    // Shift register for serial-to-parallel conversion (9 bits for stop/start bits)

    // Flops for metastability prevention
    logic sig_FF1, sig_FF2;

    // Double-flop the RX input to prevent metastability issues
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) begin
            sig_FF1 <= 1'b1;       // Default idle state for RX is high
            sig_FF2 <= 1'b1;
        end
        else begin
            sig_FF1 <= RX;      // First flip-flop captures RX
            sig_FF2 <= sig_FF1; // Second flip-flop synchronizes RX to the clock domain
        end

    // === Shift Register Logic ===
    // Serial-to-parallel conversion of received data
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            rx_shft_reg <= 9'h1FF; // Default all bits high
        else if (shift)
            rx_shft_reg <= {sig_FF2, rx_shft_reg[8:1]}; // Shift in the RX signal (LSB first)

    // Extract the 8-bit data from the shift register
    assign rx_data = rx_shft_reg[7:0];

    // === Baud Rate Control ===
    // Adjust the baud rate based on whether we are starting or receiving data
    assign baud_rate = start ? 12'd1302 : 12'd2604;

    // Baud counter logic
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            baud_cnt <= 12'h000; // Reset the baud counter
        else if (start | shift)
            baud_cnt <= baud_rate; // Reload the counter at the start of reception or after a shift
        else if (receiving)
            baud_cnt <= baud_cnt - 1; // Decrement the counter during reception

    // Determine when to shift based on baud counter reaching zero
    assign shift = (baud_cnt == 12'h000) ? 1'b1 : 1'b0;

    // === Bit Counter Logic ===
    // Count the number of bits received in the current frame
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            bit_cnt <= 4'h0; // Reset bit counter
        else if (start)
            bit_cnt <= 4'h0; // Start a new frame
        else if (shift)
            bit_cnt <= bit_cnt + 1; // Increment bit counter after each shift

    // Determine when the reception of the frame is complete
    assign done = (bit_cnt == 4'b1010) ? 1'b1 : 1'b0; // Done after receiving 10 bits (1 start, 8 data, 1 stop)

    // === State Machine ===
    typedef enum reg {IDLE, RECEIVE} state_t; // Define states: IDLE and RECEIVE

    state_t state, nxt_state; // Current and next state

    // State transition logic
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= IDLE; // Reset to IDLE state
        else
            state <= nxt_state; // Transition to the next state

    // Next-state logic and control signal generation
    always_comb begin
        // Default values for control signals
        start = 0;
        receiving = 0;
        set_rdy = 0;
        nxt_state = state;

        case (state)
            IDLE: if (~sig_FF2) begin  // Detect start bit (RX goes low)
                    start = 1;
                    nxt_state = RECEIVE; // Move to RECEIVE state
                  end

            RECEIVE: begin
                        receiving = 1;
                        if (done) begin // If the frame is complete
                            receiving = 0;
                            set_rdy = 1; // Set the ready flag
                            nxt_state = IDLE; // Return to IDLE state
                        end
                     end

            default: nxt_state = IDLE; // Default case to avoid latches
        endcase
    end

    // Generate the ready signal (`rdy`) to indicate valid data is available
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            rdy_reg <= 1'b0; // Reset the ready signal
        else if (start | clr_rdy)
            rdy_reg <= 1'b0; // Clear the ready signal on start or clr_rdy
        else if (set_rdy)
            rdy_reg <= 1'b1; // Set the ready signal when data is received

	// Assign output rdy from the rdy flop		
	assign rdy = rdy_reg;

endmodule
