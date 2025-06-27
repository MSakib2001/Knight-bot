module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, snd, cmd, done, resp);
	
	// Input and output signals
	input clk, rst_n, snd, MISO;        // clk: clock signal, rst_n: active low reset, snd: send signal, MISO: Master In Slave Out
	input [15:0] cmd;                   // 16-bit command input
	output [15:0] resp;                 // 16-bit response output
	output logic done, SS_n, SCLK, MOSI; // done: transaction completion signal, SS_n: slave select, SCLK: serial clock, MOSI: Master Out Slave In

	// Internal signals
	logic shft, init, ld_SCLK, done16, full, set_done; // control signals for shifting, initialization, SCLK loading, done indication, full status, setting done signal
	logic [15:0] shft_reg;               // 16-bit shift register to hold command data
	logic [4:0] SCLK_div, bit_cntr, bit_cntr_loader; // SCLK division counter, bit counter for transactions, loader for bit counter

	// Shift register logic to store command and shift in MISO data
	always_ff @(posedge clk)
		if (init) 
			shft_reg <= cmd;          // Load command into shift register on initialization
		else if (shft) 
			shft_reg <= {shft_reg[14:0], MISO}; // Shift in MISO data on shift trigger

	assign MOSI = shft_reg[15];         // Assign the MSB of the shift register to MOSI for transmission
	assign resp = shft_reg;             // Output the shift register content as response

	// SCLK generation logic
	always_ff @(posedge clk)
		if (ld_SCLK)
			SCLK_div <= 5'b10111;     // Load initial value for SCLK divider
		else
			SCLK_div <= SCLK_div + 1; // Increment SCLK divider

	// Assign SCLK signal from SCLK_div
	assign SCLK = SCLK_div[4];          // Use the 5th bit of the divider for SCLK output
	
	// Control logic for shifting and full status
	assign shft = (SCLK_div == 5'b10001) ? 1'b1 : 1'b0; // Trigger shift on specific SCLK_div value
	assign full = (SCLK_div == 5'b11111) ? 1'b1 : 1'b0; // Indicate when the shift register is full

	// Update bit counter based on shift status
	assign bit_cntr_loader = shft ? (bit_cntr + 1) : bit_cntr; // Increment bit counter if shifting

	// Bit counter logic
	always_ff @(posedge clk)
		if (init)
			bit_cntr <= 5'b00000;    // Reset bit counter on initialization
		else
			bit_cntr <= bit_cntr_loader; // Update bit counter based on loader

	assign done16 = bit_cntr[4] & 1;   // Indicate completion of 16 bits transfer

	// State machine definition
	typedef enum reg [1:0] {IDLE, TRANSACT, BACKPORCH} state_t; // Define states for the state machine

	state_t state, nxt_state;           // Current state and next state variables

	// State flip-flop for state transition
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;            // Reset to IDLE state on reset
		else
			state <= nxt_state;       // Update state on clock edge
	
	// State machine transition and output logic
	always_comb begin
		// Default outputs
		init = 0;                       // Initialization control signal
		ld_SCLK = 0;                    // SCLK load control signal
		set_done = 0;                   // Control signal to set done status
		nxt_state = state;              // Default next state is current state
	
		case (state)
			IDLE: if (snd) begin
					init = 1;           // Set init to 1 if send signal is asserted
					nxt_state = TRANSACT; // Transition to TRANSACT state
				  end 
				  else ld_SCLK = 1;     // Load SCLK if in IDLE and not sending
			
			TRANSACT: if (done16)
						nxt_state = BACKPORCH; // Transition to BACKPORCH if done16 is asserted
				
			BACKPORCH: if (full) begin
							set_done = 1;   // Set done when the shift register is full
							ld_SCLK = 1;    // Load SCLK for the next transaction
							nxt_state = IDLE; // Return to IDLE state
						end
			
			default: nxt_state = IDLE;    // Default transition to IDLE state
		endcase
	end 

	// Done signal flip-flop
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			done <= 1'b0;              // Reset done signal on reset
		else if (init)
			done <= 1'b0;              // Clear done signal on initialization
		else if (set_done)
			done <= 1'b1;              // Set done signal when indicated

	// Chip select (SS_n) control logic
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			SS_n <= 1'b1;              // Initialize SS_n to high on reset (inactive)
		else if (init)
			SS_n <= 1'b0;              // Assert SS_n low to select the slave during initialization
		else if (set_done)
			SS_n <= 1'b1;              // Deassert SS_n high when done

endmodule
