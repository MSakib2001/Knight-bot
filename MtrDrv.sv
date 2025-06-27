module MtrDrv(
    input clk,                     // Clock input signal
    input rst_n,                   // Asynchronous active-low reset signal
    input signed [10:0] lft_spd,   // Signed 11-bit speed control input for the left motor
    input signed [10:0] rght_spd,  // Signed 11-bit speed control input for the right motor
    output lftPWM1,                // Left motor PWM signal 1
    output lftPWM2,                // Left motor PWM signal 2 (inverted)
    output rghtPWM1,               // Right motor PWM signal 1
    output rghtPWM2                // Right motor PWM signal 2 (inverted)
);

    // Local parameter for offset coefficient
    localparam COEFF = 11'h400;    // Offset added to the speed inputs to adjust duty cycle range

    // Internal signals for adjusted speed values
    logic [10:0] lft_sum, rght_sum;

    // Add the offset to the signed speed values to ensure the duty cycle remains positive
    assign lft_sum = lft_spd + $signed(COEFF);
    assign rght_sum = rght_spd + $signed(COEFF);

    // Instantiate the left motor PWM module
    PWM11 leftmod(
        .clk(clk), 
        .rst_n(rst_n), 
        .duty(lft_sum), 
        .PWM_sig(lftPWM1), 
        .PWM_sig_n(lftPWM2)
    );

    // Instantiate the right motor PWM module
    PWM11 rightmod(
        .clk(clk), 
        .rst_n(rst_n), 
        .duty(rght_sum), 
        .PWM_sig(rghtPWM1), 
        .PWM_sig_n(rghtPWM2)
    );

endmodule
