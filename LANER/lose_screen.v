`default_nettype none

/*
 * LOSE_SCREEN.V
 * 
 * Displays "LOSER" vertically in 5 lanes when player loses (runs out of lives)
 * - L, O, S, E, R - one letter per lane
 * - Controlled by master FSM via 'enable' signal
 * - Signals 'complete' when done drawing
 */

module lose_screen(
    input wire Resetn,
    input wire Clock,
    input wire enable,              // Enable from master FSM
    output reg showing,             // High when actively drawing
    output reg complete,            // High when drawing is complete
    output wire [9:0] VGA_x,
    output wire [8:0] VGA_y,
    output wire [8:0] VGA_color,
    output wire VGA_write
);

    // VGA parameters
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;
    
    // Lane configuration
    parameter NUM_LANES = 5;
    parameter LANE_WIDTH = 80;
    parameter LANE_START_X = 120;
    
    // Letter dimensions
    parameter LETTER_WIDTH = 40;
    parameter LETTER_HEIGHT = 50;
    parameter LETTER_START_Y = 200;
    parameter LETTER_SPACING_Y = 50;
    
    // Colors
    parameter LOSE_COLOR = 9'b111_000_000;   // Red
    parameter ERASE_COLOR = 9'b000_000_000;  // Black
    
    // States
    parameter IDLE = 2'd0;
    parameter DRAWING = 2'd1;
    parameter DONE = 2'd2;
    
    reg [1:0] state;
    reg [9:0] vga_x_reg;
    reg [8:0] vga_y_reg;
    reg [8:0] vga_color_reg;
    reg vga_write_reg;
    
    // Drawing control
    reg [3:0] current_letter;
    reg [5:0] pixel_x;
    reg [5:0] pixel_y;
    
    reg enable_prev;
    wire enable_pulse;
    
    assign enable_pulse = enable && !enable_prev;
    
    wire [9:0] letter_x;
    wire [8:0] letter_y;
    wire is_pixel_on;
    
    // Calculate letter position
    function [9:0] get_letter_x;
        input [3:0] letter_idx;
        begin
            get_letter_x = LANE_START_X + (letter_idx * LANE_WIDTH) + 
                          ((LANE_WIDTH - LETTER_WIDTH) / 2);
        end
    endfunction
    
    function [8:0] get_letter_y;
        input [3:0] letter_idx;
        begin
            get_letter_y = LETTER_START_Y + (letter_idx * LETTER_SPACING_Y);
        end
    endfunction
    
    assign letter_x = get_letter_x(current_letter);
    assign letter_y = get_letter_y(current_letter);
    
    // Letter patterns for "LOSER" (5x7 grid scaled to 40x50)
    function is_letter_pixel;
        input [3:0] letter;
        input [5:0] px;
        input [5:0] py;
        reg [4:0] grid_x;
        reg [6:0] grid_y;
        begin
            grid_x = px / 8;
            grid_y = py / 7;
            
            case (letter)
                // L
                4'd0: begin
                    is_letter_pixel = (grid_x == 0) || 
                                     (grid_y == 6 && grid_x < 4);
                end
                
                // O
                4'd1: begin
                    is_letter_pixel = (grid_x == 0 && grid_y > 0 && grid_y < 6) ||
                                     (grid_x == 4 && grid_y > 0 && grid_y < 6) ||
                                     (grid_y == 0 && grid_x > 0 && grid_x < 4) ||
                                     (grid_y == 6 && grid_x > 0 && grid_x < 4);
                end
                
                // S
                4'd2: begin
                    is_letter_pixel = (grid_y == 0 && grid_x > 0) ||
                                     (grid_x == 0 && grid_y > 0 && grid_y < 3) ||
                                     (grid_y == 3 && grid_x > 0 && grid_x < 4) ||
                                     (grid_x == 4 && grid_y > 3 && grid_y < 6) ||
                                     (grid_y == 6 && grid_x < 4);
                end
                
                // E
                4'd3: begin
                    is_letter_pixel = (grid_x == 0) ||
                                     (grid_y == 0 && grid_x < 4) ||
                                     (grid_y == 3 && grid_x < 3) ||
                                     (grid_y == 6 && grid_x < 4);
                end
                
                // R
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
            showing <= 0;
            complete <= 0;
            current_letter <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            vga_write_reg <= 0;
            vga_x_reg <= 0;
            vga_y_reg <= 0;
            vga_color_reg <= LOSE_COLOR;
            enable_prev <= 0;
        end
        else begin
            enable_prev <= enable;
            
            case (state)
                IDLE: begin
                    showing <= 0;
                    complete <= 0;
                    vga_write_reg <= 0;
                    current_letter <= 0;
                    pixel_x <= 0;
                    pixel_y <= 0;
                    
                    if (enable_pulse) begin
                        state <= DRAWING;
                        showing <= 1;
                    end
                end
                
                DRAWING: begin
                    vga_x_reg <= letter_x + pixel_x;
                    vga_y_reg <= letter_y + pixel_y;
                    vga_color_reg <= is_pixel_on ? LOSE_COLOR : ERASE_COLOR;
                    vga_write_reg <= 1;
                    
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
                            
                            if (current_letter < 4) begin
                                current_letter <= current_letter + 1;
                            end
                            else begin
                                vga_write_reg <= 0;
                                showing <= 0;
                                complete <= 1;
                                state <= DONE;
                            end
                        end
                    end
                end
                
                DONE: begin
                    vga_write_reg <= 0;
                    showing <= 0;
                    complete <= 1;
                    
                    // Wait for enable to go low
                    if (!enable) begin
                        complete <= 0;
                        state <= IDLE;
                    end
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
