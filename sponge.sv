module sponge (clk, rst_n, go, piezo, piezo_n);

    input logic clk;           // 50 MHz clock input
    input logic rst_n;         // Active-low reset
    input logic go;            // Start the tune when asserted
    output logic piezo;        // Piezo speaker signal (PWM output)
    output logic piezo_n;      // Inverted piezo signal (differential drive for better sound quality)

    parameter FAST_SIM = 1;    // Simulation mode (FAST_SIM = 1 for faster simulation)

    // Increment amount for duration counter
    logic [23:0] inc_amnt = (FAST_SIM) ? 16 : 1; // Faster decrement in simulation mode

    // Variables for tracking note period and duration
    logic [15:0] note_period;      // Current note period (defines frequency of the sound)
	logic [15:0] note_period_track; // Tracks the note period for comparison
    logic [15:0] period_cnt;       // Counter for generating PWM waveform
    logic [23:0] duration_cnt;     // Counter to track note duration
	logic [23:0] duration;         // Total duration for the current note

    // State definitions for the finite state machine (FSM)
    typedef enum logic [3:0] {IDLE, D7, E7, F7, E7_LONG, F7_SHORT, D7_LONG, A6, D7_FINAL} state_t;

    state_t state, nxt_state;      // Current state and next state of the FSM

    // State Machine Logic: Updates the current state on every clock cycle
	always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)                 // On reset, set the state to IDLE
            state <= IDLE;
        else                        // Otherwise, move to the next state
            state <= nxt_state;
	
    // Control signals
	logic load, freeze; // Load: Initialize counters, Freeze: Pause counters

	// Counter Management
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			duration_cnt <= 0;          // Reset the duration counter
			period_cnt <= 0;            // Reset the period counter
			note_period_track <= 0;     // Reset the tracked note period
		end
		else if (load) begin
			duration_cnt <= duration;   // Load the new duration
			note_period_track <= note_period; // Load the new note period
			period_cnt <= 0;            // Reset the period counter to start from 0
		end
		else if (freeze) begin
			duration_cnt <= duration_cnt; // Hold the current duration counter value
			period_cnt <= period_cnt;    // Hold the current period counter value
		end
		else begin
			duration_cnt <= duration_cnt - inc_amnt; // Decrement the duration counter
			// Increment period_cnt and wrap to 0 when it reaches note_period
			if (period_cnt == note_period_track - 1) 
				period_cnt <= 0;        // Wrap around to 0
			else 
				period_cnt <= period_cnt + 1; // Increment the period counter
		end
	end

    // Next State Logic: Defines transitions and control signals for the FSM
    always_comb begin
        // Default outputs
        note_period = 0;       // Default note period
		load = 0;              // Default: Do not load new values
		freeze = 0;            // Default: Do not freeze counters
		duration = 24'hxxxxxx; // Don't care duration as default
        nxt_state = state;     // Default: Stay in the current state

        case (state)
            IDLE: begin
					freeze = 1;        // Freeze counters in IDLE
					if (go) begin      // Start tune if 'go' is asserted
						load = 1;      // Load new note values
						note_period = 16'd21285; // Frequency for D7
						duration = (1 << 23);   // Set duration
						nxt_state = D7;         // Move to D7 state
					end
				  end
				  
            D7: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd18960; // Frequency for E7
					duration = (1 << 23);   // Set duration
					nxt_state = E7;         // Move to E7 state
				end
            end

            E7: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd17895; // Frequency for F7
					duration = (1 << 23);   // Set duration
					nxt_state = F7;         // Move to F7 state
				end
            end

            F7: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd18960; // Frequency for E7
					duration = ((1 << 23) + (1 << 22)); // Set longer duration
					nxt_state = E7_LONG;    // Move to E7_LONG state
				end
            end

            E7_LONG: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd17895; // Frequency for F7
					duration = (1 << 22);   // Set shorter duration
					nxt_state = F7_SHORT;   // Move to F7_SHORT state
				end
            end

            F7_SHORT: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd21285; // Frequency for D7
					duration = ((1 << 23) + (1 << 22)); // Set longer duration
					nxt_state = D7_LONG;    // Move to D7_LONG state
				end
            end

            D7_LONG: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd28409; // Frequency for A6
					duration = (1 << 22);   // Set shorter duration
					nxt_state = A6;         // Move to A6 state
				end
            end

            A6: begin
                if (duration_cnt == 0) begin // If note duration is over
                    load = 1;      // Load new note values
					note_period = 16'd21285; // Frequency for D7
					duration = (1 << 23);   // Set duration
					nxt_state = D7_FINAL;   // Move to D7_FINAL state
				end
            end

            D7_FINAL: begin
                if (duration_cnt == 0) begin // If note duration is over
                    nxt_state = IDLE; // Go back to IDLE
					freeze = 1;      // Freeze counters
				end
            end

            default: nxt_state = IDLE; // Default to IDLE in case of invalid state
        endcase
    end

    // Output Logic: Generate piezo signals for the speaker
    assign piezo = !freeze && (period_cnt > (note_period_track >> 1)); // High for the second half of the period
    assign piezo_n = ~piezo;                          // Complementary output

endmodule
