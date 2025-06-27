module UART_tx(
    input clk,                    // Clock input signal
    input rst_n,                  // Asynchronous active-low reset signal
    input trmt,                   // Transmit request signal (starts transmission when high)
    input logic [7:0] tx_data,    // 8-bit parallel data to be transmitted
    output logic tx_done,         // Signal indicating the transmission is complete
    output logic TX               // Serial output line for UART transmission
);

    // Internal control signals
    logic init;                   // Signal to initialize transmission
    logic transmitting;           // Signal indicating data is being transmitted
    logic shift;                  // Signal to shift data into the serial output
    logic set_done;               // Signal to set the `tx_done` flag
    logic byte_valid;             // Signal indicating all bits of the frame are sent

    // Internal registers
    logic [8:0] tx_shft_reg;      // 9-bit shift register (1 start bit, 8 data bits)
    logic [11:0] baud_cnt;        // Counter for baud rate timing
    logic [3:0] bit_cnt;          // Counter to track the number of bits sent

    // Serializes the data for transmission by shifting it out bit by bit
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            tx_shft_reg <= 9'h1FF;            // Default idle state with all bits high
        else if (init)
            tx_shft_reg <= {tx_data, 1'b0};  // Load the data with a start bit (LSB = 0)
        else if (shift)
            tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // Shift out the LSB, pad with 1s (stop bits)

    // Assign the LSB of the shift register to the TX line
    assign TX = tx_shft_reg[0];

    // === Baud Counter Logic ===
    // Controls the timing for each bit based on the baud rate
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 12'h000;         // Reset baud counter
        else if (init | shift)
            baud_cnt <= 12'h000;         // Reset baud counter at the start of transmission or after a shift
        else if (transmitting)
            baud_cnt <= baud_cnt + 1;   // Increment counter while transmitting
    end

    // Generate the shift signal when the baud counter reaches the baud period (2604 in this case)
    assign shift = (baud_cnt == 12'd2604) ? 1'b1 : 1'b0;

    // === Bit Counter Logic ===
    // Counts the total number of bits transmitted in the current frame
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'h0;            // Reset bit counter
        else if (init)
            bit_cnt <= 4'h0;            // Reset bit counter at the start of transmission
        else if (shift)
            bit_cnt <= bit_cnt + 1;     // Increment counter on each shift
    end

    // Check if all bits of the frame (10 bits: 1 start, 8 data, 1 stop) have been transmitted
    assign byte_valid = (bit_cnt == 4'b1010) ? 1'b1 : 1'b0;

    // === State Machine ===
    typedef enum reg {IDLE, TRANSMIT} state_t; // Define states: IDLE and TRANSMIT

    state_t state, nxt_state; // Current and next state

    // State transition logic
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE; // Reset to IDLE state
        else
            state <= nxt_state; // Transition to the next state
    end

    // Next-state logic and control signal generation
    always_comb begin
        init = 0;
        transmitting = 0;
        set_done = 0;
        nxt_state = state;

        case (state)
            IDLE: if (trmt) begin        // If transmit request is asserted
                      init = 1;          // Initialize transmission
                      nxt_state = TRANSMIT;
                  end

            TRANSMIT: begin
                transmitting = 1;        // Indicate transmission is ongoing
                if (byte_valid) begin    // If all bits of the frame are sent
                    set_done = 1;        // Set the transmission done flag
                    nxt_state = IDLE;    // Return to IDLE state
                end
            end

            default: nxt_state = IDLE;   // Default case to avoid latches
        endcase
    end

    // === Transmission Done Signal ===
    // Controls the `tx_done` signal to indicate the end of transmission
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            tx_done <= 1'b0;             // Reset the done flag
        else if (init)
            tx_done <= 1'b0;             // Clear the done flag at the start of transmission
        else if (set_done)
            tx_done <= 1'b1;             // Set the done flag when transmission is complete
    end

endmodule
