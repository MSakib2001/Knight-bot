

module RemoteComm_e(input clk, rst_n, snd_cmd, RX, [15:0] cmd, output TX, reg cmd_snt, resp_rdy, [7:0]resp);

    logic tx_done;
    logic sel_high, trmt, set_cmd_snt, clr_rx_rdy;
    logic [7:0] tx_data;


    //only connect the transmitter parts
    UART uyart(
        .clk(clk), 
        .rst_n(rst_n), 
        .trmt(trmt), 
        .tx_data(tx_data), 
        .TX(TX), 
        .RX(RX),
        .tx_done(tx_done),
        .rx_rdy(resp_rdy),
        .clr_rx_rdy(clr_rx_rdy),
        .rx_data(resp)
    );

    reg [7:0] lsb;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            lsb <= 8'h00;
        else if (snd_cmd)
            lsb <= cmd[7:0];
    
    assign tx_data = sel_high ? cmd[15:8] : lsb;



    typedef enum logic [1:0] {IDLE, TRMT_MSB, TRMT_LSB} state_t;

    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        sel_high = 1'b0;
        trmt = 1'b0;
        set_cmd_snt = 1'b0;
        clr_rx_rdy = 1'b0;

        case (state)
            //wait for instruction to send command
            IDLE: begin
                if (snd_cmd) begin
                    //send high byte
                    clr_rx_rdy = 1'b1;
                    nxt_state = TRMT_MSB;
                    sel_high = 1'b1;
                    trmt = 1'b1;
                end
            end

            //wait till MSB trasmitted
            TRMT_MSB: begin
                if (tx_done) begin
                    //send low byte
                    nxt_state = TRMT_LSB;
                    trmt = 1'b1;
                end
                
            end

            //wait till LSB transmitted
            TRMT_LSB: begin
                if (tx_done) begin
                    nxt_state = IDLE;
                    set_cmd_snt = 1'b1;
                end
            end

            default: begin
                nxt_state = IDLE;
            end
        endcase
    end

    //flop for cmd_sent

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            cmd_snt <= 1'b0;
        else if (snd_cmd)
            cmd_snt <= 1'b0;
        else if (set_cmd_snt)
            cmd_snt <= 1'b1;
    end

endmodule
