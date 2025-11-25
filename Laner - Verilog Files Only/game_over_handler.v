//Manages the player's lives system and game over state

`default_nettype none

module game_over_handler(
    input wire Resetn,
    input wire Clock,
    input wire collision,
    input wire restart_key,
    output reg game_over,
    output reg [1:0] lives,          // 0-3 lives use 4 bits to rep
    output reg clear_score,         //for resets so that the score can start at 0 and lived redo at 3
    output wire [6:0] HEX_display    // Display lives on HEX
);
    reg collision_prev;  // Previous collision state
    reg restart_key_prev; 
    

    always @(posedge Clock) begin
        if (!Resetn) 
        begin
            game_over <= 0;
            lives <= 2'd3;      // Start with 3 lives
            collision_prev <= 0;
            restart_key_prev <= 0;
            clear_score <= 0;
        end
        else 
        begin
            collision_prev <= collision;
            restart_key_prev <= restart_key;
            clear_score <= 0;  // Default to 0
            
            // Detect restart key
            // If game is over and restart key is pressed, reset the game

            if (restart_key && !restart_key_prev && game_over) 
            begin
                game_over <= 0;     
                lives <= 2'd3;       // Reset to 3 lives
                clear_score <= 1; 
            end
            // Detect new collision
            else if (collision && !collision_prev && !game_over) 
            begin
                if (lives > 0) begin
                    lives <= lives - 1;  // Lose a life
                    
                    // Check if this was the last life
                    if (lives == 1) 
                    begin
                        game_over <= 1;  // Game over when going from 1 to 0 lives
                    end
                end
            end
        end
    end
    
    // shows the current number of lives remaining
    hex_decoder lives_display(
        .hex_digit(lives),
        .segments(HEX_display)
    );
endmodule

module hex_decoder(
    input wire [1:0] hex_digit,
    output reg [6:0] segments
);
        
    always @(*) begin
        case (hex_digit)
            2'd0: segments = 7'b1000000;  // Display "0"
            2'd1: segments = 7'b1111001; 
            2'd2: segments = 7'b0100100;
            2'd3: segments = 7'b0110000; 
            default: segments = 7'b1111111;  // Blank
        endcase
    end
    
endmodule