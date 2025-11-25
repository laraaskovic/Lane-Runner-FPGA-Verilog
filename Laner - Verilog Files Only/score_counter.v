`default_nettype none

module score_counter(
    input wire Resetn,
    input wire Clock,
    input wire score_increment,  
    output reg [9:0] score,    
    output wire [6:0] HEX0,  
    output wire [6:0] HEX1, 
    output wire [6:0] HEX2 
);
    // Decimal digits for display
    reg [3:0] ones;
    reg [3:0] tens;
    reg [3:0] hundreds;
    
    reg score_increment_prev;
    wire score_increment_pulse;
    
    assign score_increment_pulse = score_increment && !score_increment_prev;
    
    always @(posedge Clock) begin
        if (!Resetn) 
        begin
            score <= 10'd0; //resert to 0
            ones <= 4'd0;
            tens <= 4'd0;
            hundreds <= 4'd0;
            score_increment_prev <= 1'b0;
        end
        else 
        begin
            score_increment_prev <= score_increment;
            
            if (score_increment_pulse && score < 10'd999) 
            begin
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

module hex_decoderr( //taken from lab
    input wire [3:0] hex_digit,
    output reg [6:0] segments
);     
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