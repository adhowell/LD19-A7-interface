`timescale 1ns / 1ps

module uart_rx ( clk, rx_data, data_out, ready, error, recog );
    input clk;
    input rx_data;
    output reg [7:0] data_out;
    output reg ready = 0;
    output reg error = 0;
    
    output [1:0] recog;
        
    localparam INIT = 2'b00, INIT_HIGH = 2'b10, START_TX = 2'b11;
    reg [1:0] init_state = INIT;
        
    assign recog = init_state;
        
    localparam NULL = 3'b000, RDY = 3'b001, START = 3'b010, RECEIVE=3'b011, WAIT=3'b100, CHECK=3'b101;
    reg [2:0] state = NULL;
    
    // Based on 12MHz clock and target baud of 230400
    // Gives error rate of 0.16% - too much???
    localparam [5:0] baud_timer = 6'b110100;
    
    reg [5:0] timer = 6'b0;
    reg [3:0] bit_index = 4'b0;
    reg [8:0] rx_buffer;
    
    always @ (posedge clk)
    begin
    
    case (init_state)
    INIT:
        if (rx_data == 1'b1)
        begin
            init_state <= INIT_HIGH;
        end
    INIT_HIGH:
        if (rx_data == 1'b0)
        begin
            init_state <= START_TX;
            state <= RDY;
        end
    endcase
    
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
        begin
            ready <= 1'b1;
            state <= WAIT;
            data_out <= rx_buffer[7:0];
        end
    endcase
    
    end
endmodule

module ld19_rx_top( uart_rx, sysclk, led, led0_r, led0_g, led0_b );
    input uart_rx;
    input sysclk;
    output [1:0] led;
    output led0_r;
    output led0_g;
    output led0_b;
    
    wire [7:0] data_out_buffer;
    wire ready;
    wire error;
    wire [1:0] init_complete;
    
    uart_rx uart_mod (
        .clk(sysclk),
        .rx_data(uart_rx),
        .data_out(data_out_buffer),
        .ready(ready),
        .error(error),
        .recog(init_complete)
    );
    
    // Packet size is 300 bytes according to SDK
    localparam [31:0] packet_size = 300;
    localparam [31:0] one_second_packets = 5; //801;
    localparam [7:0] header = 8'b01010100;
    reg [31:0] packet_byte = 32'b0;
    reg [31:0] packets = 32'b0;
    reg [31:0] sum_errors = 32'b0;
    reg [1:0] led_state = 2'b0;
    reg reset = 1'b0;
    reg one_second_indicator = 1'b0;
    
    always @ (posedge ready)
    begin
    
    if (packets == one_second_packets)
    begin
        if (sum_errors > 4)
            led_state <= 2'b11;
        else 
        begin
            if (sum_errors > 2)
                led_state <= 2'b10;
            else 
            begin 
                if (sum_errors > 0)
                    led_state <= 2'b01;
                else
                    led_state <= 2'b00;
            end
        end
        reset <= 1'b1;
    end
    else
    begin
        if (packet_byte == packet_size)
        begin
            packets <= packets + 1'b1;
            packet_byte <= 32'b0;
        end
        else
        begin
            if (packet_byte == 32'b0)
            begin
                packet_byte <= packet_byte + 1;
                if ((data_out_buffer ^ header) != 8'b0)
                    sum_errors <= sum_errors + 1;
            end
            else
                packet_byte <= packet_byte + 1;
        end
    end 
    
    if (reset == 1'b1)
    begin
        sum_errors <= 32'b0;
        packets <= 32'b0;
        packet_byte <= 32'b0;
        reset <= 1'b0;
        led_state <= 2'b00;
        one_second_indicator <= ~one_second_indicator;
    end

    end 
    
    //assign led[1] = led_state[1];
    //assign led[0] = led_state[0];
    //assign led0_r = one_second_indicator;
    assign led0_r = one_second_indicator;
    assign led0_g = 1'b1;
    assign led0_b = 1'b1;
    assign led[1] = led_state[1];
    assign led[0] = led_state[0];
    
endmodule
