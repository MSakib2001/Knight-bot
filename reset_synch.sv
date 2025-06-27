module rst_synch(
    input clk,             // Clock input signal
    input RST_n,           // Asynchronous active-low reset input signal
    output logic rst_n      // Synchronized active-low reset output signal
);

    // Internal logic signals used as flip-flop outputs for synchronization
    logic flop_one, flop_two;

    // Always block triggered on the negative edge of the clock (negedge clk) 
    // or the asynchronous reset signal (negedge RST_n)
    always_ff @(negedge clk, negedge RST_n)
        if (!RST_n) begin
            // Asynchronous reset: when RST_n is low, both flip-flops are reset to 0
            flop_one <= 1'b0;
            flop_two <= 1'b0;
        end
        else begin
            // Synchronization logic: 
            // - flop_one captures a logic '1' (indicating reset deassertion)
            // - flop_two captures the value of flop_one, creating a two-stage pipeline
            flop_one <= 1'b1;
            flop_two <= flop_one;
        end

    // Assign the value of the second flip-flop (flop_two) to the synchronized reset output
    // This ensures the reset signal (rst_n) is synchronized to the clock domain
    assign rst_n = flop_two;

endmodule

