`default_nettype none

/*
 * SCORE_COUNTER.V
 * 
 * Manages game scoring system:
 * - Increments score when obstacles pass the player
 * - Displays score on three 7-segment displays (HEX0, HEX1, HEX2)
 * - Maximum score is 999
 * - Resets to 0 on reset
 */

module score_counter(
    input wire Resetn,
    input wire Clock,
    input wire score_increment,     // Pulse high to increment score
    output reg [9:0] score,         // Current score (0-999)
    output wire [6:0] HEX0,         // Ones digit
    output wire [6:0] HEX1,         // Tens digit
    output wire [6:0] HEX2          // Hundreds digit
);

    // Decimal digits for display
    reg [3:0] ones;
    reg [3:0] tens;
    reg [3:0] hundreds;
    
    // Edge detection for score_increment
    reg score_increment_prev;
    wire score_increment_pulse;
    
    // Detect rising edge of score_increment signal
    assign score_increment_pulse = score_increment && !score_increment_prev;
    
    always @(posedge Clock) begin
        if (!Resetn) begin
            score <= 10'd0;
            ones <= 4'd0;
            tens <= 4'd0;
            hundreds <= 4'd0;
            score_increment_prev <= 1'b0;
        end
        else begin
            score_increment_prev <= score_increment;
            
            // Increment score on pulse (if not at max)
            if (score_increment_pulse && score < 10'd999) begin
                score <= score + 1;
                
                // Update decimal digits
                if (ones == 4'd9) begin
                    ones <= 4'd0;
                    if (tens == 4'd9) begin
                        tens <= 4'd0;
                        if (hundreds < 4'd9)
                            hundreds <= hundreds + 1;
                    end
                    else
                        tens <= tens + 1;
                end
                else
                    ones <= ones + 1;
            end
        end
    end
    
    // 7-segment decoders for each digit
    hex_decoderr ones_display(
        .hex_digit(ones),
        .segments(HEX0)
    );
    
    hex_decoderr tens_display(
        .hex_digit(tens),
        .segments(HEX1)
    );
    
    hex_decoderr hundreds_display(
        .hex_digit(hundreds),
        .segments(HEX2)
    );

endmodule

// 7-segment display decoder (0-9)
module hex_decoderr(
    input wire [3:0] hex_digit,
    output reg [6:0] segments
);
    
    // segments encoding: {g, f, e, d, c, b, a}
    // Active low (0 = ON, 1 = OFF)
    
    always @(*) begin
        case (hex_digit)
            4'd0: segments = 7'b1000000;  // Display "0"
            4'd1: segments = 7'b1111001;  // Display "1"
            4'd2: segments = 7'b0100100;  // Display "2"
            4'd3: segments = 7'b0110000;  // Display "3"
            4'd4: segments = 7'b0011001;  // Display "4"
            4'd5: segments = 7'b0010010;  // Display "5"
            4'd6: segments = 7'b0000010;  // Display "6"
            4'd7: segments = 7'b1111000;  // Display "7"
            4'd8: segments = 7'b0000000;  // Display "8"
            4'd9: segments = 7'b0010000;  // Display "9"
            default: segments = 7'b1111111;  // Blank
        endcase
    end
    
endmodule
