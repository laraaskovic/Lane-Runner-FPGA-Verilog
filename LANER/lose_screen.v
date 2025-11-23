`default_nettype none

//displayes 'LOSER' on screen

module lose_screen(
    input wire Resetn,
    input wire Clock,
    input wire enable,             
    output reg showing,             
    output reg complete,       
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
            get_letter_x = LANE_START_X + (letter_idx * LANE_WIDTH) + ((LANE_WIDTH - LETTER_WIDTH) / 2);
        end
    endfunction

    //letters staggered vertically for a diagonal effect!!!
    
    function [8:0] get_letter_y;
        input [3:0] letter_idx;
        begin
            get_letter_y = LETTER_START_Y + (letter_idx * LETTER_SPACING_Y);
        end
    endfunction
    
    assign letter_x = get_letter_x(current_letter);
    assign letter_y = get_letter_y(current_letter);
    
    function is_letter_pixel;
        input [3:0] letter; //letter being drawn
        input [5:0] px;
        input [5:0] py;

        //convert to lane
        reg [4:0] grid_x;
        reg [6:0] grid_y;

        begin
            grid_x = px / 8; //40 px
            grid_y = py / 7; //50 px
            
            case (letter)
                // L
                4'd0: begin
                    is_letter_pixel = (grid_x == 0) ||  //left vertical edge
                                     (grid_y == 6 && grid_x < 4); bottom
                end
                
                // O
                4'd1: begin
                    is_letter_pixel = (grid_x == 0 && grid_y > 0 && grid_y < 6) ||  //left vert
                                     (grid_x == 4 && grid_y > 0 && grid_y < 6) || //right vert
                                     (grid_y == 0 && grid_x > 0 && grid_x < 4) || //left horz
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
                                     (grid_y > 3 && grid_x == (grid_y - 3)); //diagonal leg
                end
                
                default: is_letter_pixel = 0;
            endcase
        end
    endfunction
    
    assign is_pixel_on = is_letter_pixel(current_letter, pixel_x, pixel_y); //determine if draw
    
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
        else 
        begin
            enable_prev <= enable;
            
            case (state)
                IDLE:  //default state wait until show anything
                begin
                    showing <= 0;
                    complete <= 0;
                    vga_write_reg <= 0;
                    current_letter <= 0;
                    pixel_x <= 0;
                    pixel_y <= 0;
                    
                    if (enable_pulse) 
                    begin
                        state <= DRAWING; //start drawing!
                        showing <= 1;
                    end
                end
                
                DRAWING: 
                begin
                    vga_x_reg <= letter_x + pixel_x;
                    vga_y_reg <= letter_y + pixel_y;
                    vga_color_reg <= is_pixel_on ? LOSE_COLOR : ERASE_COLOR; //know the correct parts of the letter
                    vga_write_reg <= 1;
                    
                    if (pixel_x < LETTER_WIDTH - 1) begin
                        pixel_x <= pixel_x + 1; //not done
                    end
                    else 
                    begin
                        pixel_x <= 0;
                        if (pixel_y < LETTER_HEIGHT - 1) 
                        begin
                            pixel_y <= pixel_y + 1; //acts like a for loop
                        end
                        else 
                        begin
                            pixel_y <= 0;
                            //move to next letteer
                            
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
                
                DONE:  //wait for trigger, prevents drawing over and ove agin
                begin
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
