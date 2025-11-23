`default_nettype none

/*
 * TITLE_SCREEN.V
 * 
 * Displays "LANE RUNNER" title screen with letters in lanes
 * and waits for KEY[3] to start the game
 * 
 * Layout:
 * - 5 letters arranged vertically, one in each lane: L, A, N, E, R
 * - Each letter is 40x50 pixels, centered in its lane
 * - Only draws within lane boundaries (120-520 X range)
 * - Erases title before game starts
 */

module title_screen(
    input wire Resetn,
    input wire Clock,
    input wire start_key,           // KEY[3] to start game
    output reg showing_title,       // High when title is active
    output reg title_complete,      // High when ready to start game
    output wire [9:0] VGA_x,
    output wire [8:0] VGA_y,
    output wire [8:0] VGA_color,
    output wire VGA_write
);

    // VGA parameters
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;
    
    // Lane configuration - must match game settings
    parameter NUM_LANES = 5;
    parameter LANE_WIDTH = 80;
    parameter LANE_START_X = 120;
    
    // Letter dimensions
    parameter LETTER_WIDTH = 40;
    parameter LETTER_HEIGHT = 50;
    parameter LETTER_START_Y = 150;  // Starting Y position for letters
    parameter LETTER_SPACING_Y = 55; // Vertical spacing between letters
    
    // Colors
    parameter TITLE_COLOR = 9'b111_111_000;  // Yellow
    parameter ERASE_COLOR = 9'b000_000_000;  // Black
    
    // States
    parameter IDLE = 3'd0;
    parameter DRAW_TITLE = 3'd1;
    parameter WAIT_START = 3'd2;
    parameter ERASE_TITLE = 3'd3;
    parameter DONE = 3'd4;
    
    reg [2:0] state;
    reg [9:0] vga_x_reg;
    reg [8:0] vga_y_reg;
    reg [8:0] vga_color_reg;
    reg vga_write_reg;
    
    // Drawing control
    reg [3:0] current_letter;  // Which letter we're drawing (0-4 for L,A,N,E,R)
    reg [5:0] pixel_x;
    reg [5:0] pixel_y;
    reg start_key_prev;
    
    wire [9:0] letter_x;
    wire [8:0] letter_y;
    wire is_pixel_on;
    
    // Calculate letter position based on current_letter
    function [9:0] get_letter_x;
        input [3:0] letter_idx;
        begin
            // Each letter is centered in its lane
            get_letter_x = LANE_START_X + (letter_idx * LANE_WIDTH) + 
                          ((LANE_WIDTH - LETTER_WIDTH) / 2);
        end
    endfunction
    
    function [8:0] get_letter_y;
        input [3:0] letter_idx;
        begin
            // Letters stacked vertically with spacing
            get_letter_y = LETTER_START_Y + (letter_idx * LETTER_SPACING_Y);
        end
    endfunction
    
    assign letter_x = get_letter_x(current_letter);
    assign letter_y = get_letter_y(current_letter);
    
    // Letter patterns using 5x7 grid (scaled up to 40x50)
    function is_letter_pixel;
        input [3:0] letter;
        input [5:0] px;
        input [5:0] py;
        reg [4:0] grid_x;
        reg [6:0] grid_y;
        begin
            // Scale down to 5x7 grid
            grid_x = px / 8;  // 40 pixels / 8 = 5 columns
            grid_y = py / 7;  // 50 pixels / 7 ≈ 7 rows
            
            case (letter)
                // L (Lane 0)
                4'd0: begin
                    is_letter_pixel = (grid_x == 0) || 
                                     (grid_y == 6 && grid_x < 4);
                end
                
                // A (Lane 1)
                4'd1: begin
                    is_letter_pixel = (grid_x == 0 && grid_y > 1) ||
                                     (grid_x == 4 && grid_y > 1) ||
                                     (grid_y == 1 && grid_x > 0 && grid_x < 4) ||
                                     (grid_y == 3 && grid_x > 0 && grid_x < 4);
                end
                
                // N (Lane 2)
                4'd2: begin
                    is_letter_pixel = (grid_x == 0) ||
                                     (grid_x == 4) ||
                                     (grid_x == grid_y && grid_y > 0 && grid_y < 6);
                end
                
                // E (Lane 3)
                4'd3: begin
                    is_letter_pixel = (grid_x == 0) ||
                                     (grid_y == 0 && grid_x < 4) ||
                                     (grid_y == 3 && grid_x < 3) ||
                                     (grid_y == 6 && grid_x < 4);
                end
                
                // R (Lane 4)
                4'd4: begin
                    is_letter_pixel = (grid_x == 0) ||
                                     (grid_y < 3 && grid_x == 4) ||
                                     ((grid_y == 0 || grid_y == 3) && grid_x > 0 && grid_x < 4) ||
                                     (grid_y > 3 && grid_x == (grid_y - 3));
                end
                
                default: is_letter_pixel = 0;
            endcase
        end
    endfunction
    
    assign is_pixel_on = is_letter_pixel(current_letter, pixel_x, pixel_y);
    
    // FSM
    always @(posedge Clock) begin
        if (!Resetn) begin
            state <= IDLE;
            showing_title <= 1;
            title_complete <= 0;
            current_letter <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            vga_write_reg <= 0;
            vga_x_reg <= 0;
            vga_y_reg <= 0;
            vga_color_reg <= TITLE_COLOR;
            start_key_prev <= 0;
        end
        else begin
            start_key_prev <= start_key;
            
            case (state)
                // ==========================================
                IDLE: begin
                    showing_title <= 1;
                    title_complete <= 0;
                    current_letter <= 0;
                    pixel_x <= 0;
                    pixel_y <= 0;
                    vga_write_reg <= 0;
                    state <= DRAW_TITLE;
                end
                
                // ==========================================
                DRAW_TITLE: begin
                    // Draw current letter pixel by pixel
                    vga_x_reg <= letter_x + pixel_x;
                    vga_y_reg <= letter_y + pixel_y;
                    vga_color_reg <= is_pixel_on ? TITLE_COLOR : ERASE_COLOR;
                    vga_write_reg <= 1;
                    
                    // Scan through pixels
                    if (pixel_x < LETTER_WIDTH - 1) begin
                        pixel_x <= pixel_x + 1;
                    end
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < LETTER_HEIGHT - 1) begin
                            pixel_y <= pixel_y + 1;
                        end
                        else begin
                            pixel_y <= 0;
                            
                            // Move to next letter
                            if (current_letter < 4) begin  // 5 letters (0-4)
                                current_letter <= current_letter + 1;
                            end
                            else begin
                                // All letters drawn
                                vga_write_reg <= 0;
                                current_letter <= 0;
                                state <= WAIT_START;
                            end
                        end
                    end
                end
                
                // ==========================================
                WAIT_START: begin
                    vga_write_reg <= 0;
                    
                    // Detect rising edge of start key (KEY[3])
                    if (start_key && !start_key_prev) begin
                        current_letter <= 0;
                        pixel_x <= 0;
                        pixel_y <= 0;
                        state <= ERASE_TITLE;
                    end
                end
                
                // ==========================================
                ERASE_TITLE: begin
                    // Erase current letter by drawing black
                    vga_x_reg <= letter_x + pixel_x;
                    vga_y_reg <= letter_y + pixel_y;
                    vga_color_reg <= ERASE_COLOR;
                    vga_write_reg <= 1;
                    
                    // Scan through pixels
                    if (pixel_x < LETTER_WIDTH - 1) begin
                        pixel_x <= pixel_x + 1;
                    end
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < LETTER_HEIGHT - 1) begin
                            pixel_y <= pixel_y + 1;
                        end
                        else begin
                            pixel_y <= 0;
                            
                            // Move to next letter
                            if (current_letter < 4) begin
                                current_letter <= current_letter + 1;
                            end
                            else begin
                                // All letters erased
                                vga_write_reg <= 0;
                                state <= DONE;
                            end
                        end
                    end
                end
                
                // ==========================================
                DONE: begin
                    showing_title <= 0;
                    title_complete <= 1;
                    vga_write_reg <= 0;
                    // Stay in this state
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign VGA_x = vga_x_reg;
    assign VGA_y = vga_y_reg;
    assign VGA_color = vga_color_reg;
    assign VGA_write = vga_write_reg;

endmodule
