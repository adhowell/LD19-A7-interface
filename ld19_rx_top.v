`timescale 1ns / 1ps

module uart_rx ( clk, rx_data, data_out, ready, error );
    input clk;
    input rx_data;
    output reg [7:0] data_out;
    output reg ready = 0;
    output reg error = 0;
        
    localparam RDY = 3'b000, START = 3'b001, RECEIVE=3'b010, WAIT=3'b011, CHECK=3'b100;
    reg [2:0] state = RDY;
    
    // Based on 12MHz clock and target baud of 230400
    // Gives error rate of 0.16% - too much???
    localparam [5:0] baud_timer = 6'b110100;
    
    reg [5:0] timer = 6'b0;
    reg [3:0] bit_index = 4'b0;
    reg [8:0] rx_buffer;
    
    always @ (posedge clk)
    
    case (state)
    RDY:
        if (rx_data == 1'b0)
        begin
            state <= START;
            bit_index <= 4'b0;
        end
    START:
        if (timer == baud_timer/2)
        begin
            state <= WAIT;
            timer <= 6'b0;
            error <= 1'b0;
            ready <= 1'b0;
        end
        else
            timer <= timer + 1'b1;
    WAIT:
        if (timer == baud_timer)
        begin
            timer <= 6'b0;
            if (ready)
                state <= RDY;
            else
                state <= RECEIVE;
        end
        else
            timer <= timer + 1'b1;
    RECEIVE:
        begin
            rx_buffer[bit_index] <= rx_data;
            bit_index <= bit_index + 1'b1;
            if (bit_index == 4'b1000)
                state <= CHECK;
            else
                state <= WAIT;
        end
    CHECK:
        // Assuming non-null packets are valid
        // Pretty dumb but can't think of anything better until I add stuff for decoding the packet data
        if (|rx_buffer[7:0] == 0)
        begin
            ready <= 1'b1;
            data_out[7:0] <= 8'bx;
            error <= 1'b1;
            state <= RDY;
        end
        else
        begin
            ready <= 1'b1;
            state <= WAIT;
            data_out <= rx_buffer[7:0];
        end
    endcase
endmodule

module ld19_rx_top( uart_rx, sysclk, led, led0_r );
    input uart_rx;
    input sysclk;
    output [1:0] led;
    output led0_r;
    
    wire [7:0] data_out_buffer;
    wire ready;
    wire error;
    
    uart_rx uart_mod (
        .clk(sysclk),
        .rx_data(uart_rx),
        .data_out(data_out_buffer),
        .ready(ready),
        .error(error)
    );
    
    // For baud rate of 230400 and packet size of 8+1 bits
    localparam [31:0] one_second_packets = 25600;
    reg [31:0] packets = 32'b0;
    reg [31:0] sum_errors = 32'b0;
    reg [1:0] led_state = 2'b0;
    reg reset = 1'b0;
    reg one_second_indicator = 1'b0;
    
    always @ (posedge ready)
    begin
    
    if (packets == one_second_packets)
    begin
        if (sum_errors > 1000)
            led_state <= 2'b11;
        else 
        begin
            if (sum_errors > 100)
                led_state <= 2'b10;
            else 
            begin 
                if (sum_errors > 10)
                    led_state <= 2'b01;
                else
                    led_state <= 2'b00;
            end
        end
        reset <= 1'b1;
    end
    else
        sum_errors <= sum_errors + error;
    
    if (reset == 1'b1)
    begin
        sum_errors <= 32'b0;
        packets <= 32'b0;
        reset <= 1'b0;
        led_state <= 2'b00;
        one_second_indicator <= ~one_second_indicator;
    end
    
    packets = packets + 1'b1;
    
    end 
    
    assign led[1] = led_state[1];
    assign led[0] = led_state[0];
    assign led0_r = one_second_indicator;
    
endmodule
