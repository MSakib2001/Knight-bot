module UART_wrapper(clr_cmd_rdy, cmd_rdy, cmd, trmt, resp, tx_done, clk, rst_n, RX, TX);
	
	// Input and output signals
	input logic clr_cmd_rdy, clk, rst_n, RX, trmt; // clr_cmd_rdy: clear command ready signal, clk: clock signal, rst_n: active low reset, RX: receive data, trmt: transmit signal
	input logic [7:0] resp;                        // 8-bit response data to be transmitted
	output [15:0] cmd;                             // 16-bit command output
	output logic tx_done, TX;                      // tx_done: transmission done signal, TX: transmit data
	output logic cmd_rdy;                          // cmd_rdy: command ready signal

	// Internal output signals for UART Wrapper State Machine
	logic clr_rdy, store, rx_rdy;                 // clr_rdy: clear receive ready signal, store: signal to store received data, rx_rdy: receive ready signal
	logic [7:0] rx_data;                          // 8-bit received data
	logic set_cmd_rdy;                            // signal to set command ready

	// Internal high byte storing flip-flop
	logic [7:0] FF_sig;                           // 8-bit register to hold high byte of command

	// Instantiate UART module
	UART iUart(.clk(clk), 
				.rst_n(rst_n), 
				.TX(TX), 
				.RX(RX), 
				.trmt(trmt), 
				.tx_data(resp),      // Connect response data to UART transmit
				.rx_data(rx_data),   // Connect received data to UART receive
				.tx_done(tx_done), 
				.clr_rx_rdy(clr_rdy), // Clear receive ready signal
				.rx_rdy(rx_rdy));     // Receive ready signal from UART
	
	// High byte storing flip-flop and select mux logic
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			FF_sig <= 16'h0000;  // Reset high byte register to zero
		else if (store)
			FF_sig <= rx_data;   // Store received data into the high byte register when signaled

	// Command output concatenation
	assign cmd = {FF_sig, rx_data}; // Combine high byte and low byte to form command output
	
	// State machine states
	typedef enum reg {IDLE, HIGHBYTE} state_t; // Define states for state machine

	state_t state, nxt_state; // Current state and next state variables
	
	// Infer state flip-flop for state transitions
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;       // Reset to IDLE state on reset
		else
			state <= nxt_state;  // Update state on clock edge
			
	// State machine logic
	always_comb begin
		// Default outputs
		store = 0;                // Default store signal
		clr_rdy = 0;              // Default clear receive ready signal
		set_cmd_rdy = 0;         // Default set command ready signal
		nxt_state = state;        // Default next state is current state

		case (state)
			IDLE: if (rx_rdy) begin // Check if receive is ready
					store = 1;       // Signal to store received data
					clr_rdy = 1;     // Clear UART receive ready
					nxt_state = HIGHBYTE; // Transition to HIGHBYTE state
				  end
			
			HIGHBYTE: if (rx_rdy) begin // In HIGHBYTE state, check if receive is ready again
						clr_rdy = 1;   // Clear UART receive ready
						set_cmd_rdy = 1; // Set command ready signal
						nxt_state = IDLE; // Transition back to IDLE state
					  end
			
			// Default case
			default: nxt_state = IDLE; // Return to IDLE for any undefined state
		endcase
	end
	
	// Flip-flop to control cmd_rdy based on clr_cmd_rdy signal
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			cmd_rdy <= 1'b0;      // Reset cmd_rdy to low on reset
		else if (clr_cmd_rdy)
			cmd_rdy <= 1'b0;      // Clear cmd_rdy when clr_cmd_rdy is asserted
		else if (set_cmd_rdy)
			cmd_rdy <= 1'b1;      // Set cmd_rdy high when ready

endmodule
