module PWM11(
    input clk,                // Clock input signal
    input rst_n,              // Asynchronous active-low reset signal
    input [10:0] duty,        // 11-bit input representing the duty cycle
    output logic PWM_sig,     // PWM output signal
    output logic PWM_sig_n    // Inverted PWM output signal
);

    // Internal logic signals
    logic cnt_lt_duty;        // Signal indicating if the counter value is less than the duty cycle
    logic [10:0] cnt;         // 11-bit counter for PWM generation
    logic [10:0] cnt_inc;     // Incremented value of the counter

    // Calculate the next value of the counter by incrementing the current counter value by 1
    assign cnt_inc = cnt + 1'b1;

    // Compare the current counter value with the duty cycle to determine the PWM signal state
    assign cnt_lt_duty = (cnt < duty);

    // Counter logic: Increment the counter on each positive clock edge or reset it asynchronously
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            cnt <= 11'h000;   // Asynchronous reset: Set the counter to 0
        else
            cnt <= cnt_inc;   // Increment the counter at each clock cycle
    end

    // PWM signal generation logic: 
    // - Generate PWM_sig based on the comparison between counter and duty cycle
    // - PWM_sig is high if counter is less than the duty cycle
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            PWM_sig <= 1'b0;  // Asynchronous reset: Set PWM output to 0
        else
            PWM_sig <= cnt_lt_duty; // Update PWM signal based on comparison result
    end

    // Generate the inverted PWM signal
    assign PWM_sig_n = ~PWM_sig; // PWM_sig_n is always the logical complement of PWM_sig

endmodule
