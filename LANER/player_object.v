/*
 * PLAYER_OBJECT.V with ROM Image Support
 *
 * - Draws player from ROM images
 * - Normal image when not in collision
 * - Invincible image when in collision mode (2 seconds)
 * - Continuously redraws during collision to maintain priority
 */

`default_nettype none

module player_object(
    input wire Resetn,
    input wire Clock,
    input wire move_left,
    input wire move_right,
    input wire collision,
    output reg [2:0] player_lane,
    output wire [nX-1:0] VGA_x,
    output wire [nY-1:0] VGA_y,
    output wire [COLOR_DEPTH-1:0] VGA_color,
    output wire VGA_write,
    output wire is_erasing,
    output wire is_drawing,
    output wire is_collision_mode
);

    parameter nX = 10;
    parameter nY = 9;
    parameter COLOR_DEPTH = 9;
   
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;
   
    parameter NUM_LANES = 5;
    parameter LANE_WIDTH = 80;
    parameter LANE_START_X = 120;
   
    parameter PLAYER_WIDTH = 60;
    parameter PLAYER_HEIGHT = 60;
    parameter PLAYER_Y_POS = 360;
   
    parameter ERASE_COLOR  = 9'b000_000_000;
   
    // Collision timer - 2 seconds at 50MHz
    parameter COLLISION_DURATION = 27'd100_000_000;
    parameter REDRAW_INTERVAL = 23'd500_000;
   
    // FSM States
    parameter INIT = 3'd0;
    parameter DRAW_INITIAL = 3'd1;
    parameter IDLE = 3'd2;
    parameter ERASE = 3'd3;
    parameter DRAW = 3'd4;
    parameter COLLISION_REDRAW = 3'd5;
   
    reg [2:0] state;
    reg [2:0] next_state_after_draw;
    reg [nX-1:0] player_x_pos;
    reg [nX-1:0] prev_x_pos;
    reg [5:0] pixel_x;
    reg [5:0] pixel_y;
   
    reg [nX-1:0] vga_x_reg;
    reg [nY-1:0] vga_y_reg;
    reg [COLOR_DEPTH-1:0] vga_color_reg;
    reg vga_write_reg;
   
    reg input_handled;
    
    // Collision state tracking
    reg collision_prev;
    reg in_collision_mode;
    reg in_collision_mode_prev;  // Track previous collision mode state
    reg [26:0] collision_timer;
    reg [22:0] redraw_counter;
    
    // ROM interface for player images
    wire [11:0] rom_address;
    wire [8:0] rom_data_normal;      // Normal player image
    wire [8:0] rom_data_invincible;  // Invincible player image
    
    // ROM address calculation: pixel_y * 60 + pixel_x
    assign rom_address = (pixel_y * 60) + pixel_x;
    
    // Select which ROM data to use
    wire [8:0] selected_rom_data;
    assign selected_rom_data = in_collision_mode ? rom_data_invincible : rom_data_normal;
    
    // Instantiate player image ROMs
    player_rom_normal PLAYER_NORMAL (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_normal)
    );
    
    player_rom_invincible PLAYER_INVINCIBLE (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_invincible)
    );
   
    function [nX-1:0] lane_to_x;
        input [2:0] lane;
        begin
            lane_to_x = LANE_START_X + (lane * LANE_WIDTH) +
                       ((LANE_WIDTH - PLAYER_WIDTH) / 2);
        end
    endfunction

    always @(posedge Clock) begin
        if (!Resetn) begin
            state <= INIT;
            next_state_after_draw <= IDLE;
            player_lane <= 3'd2;
            player_x_pos <= 10'd0;
            prev_x_pos <= 10'd0;
            pixel_x <= 0;
            pixel_y <= 0;
            vga_x_reg <= 10'd0;
            vga_y_reg <= 9'd0;
            vga_write_reg <= 0;
            vga_color_reg <= 9'd0;
            input_handled <= 0;
            collision_prev <= 0;
            in_collision_mode <= 0;
            in_collision_mode_prev <= 0;
            collision_timer <= 0;
            redraw_counter <= 0;
        end
        else begin
            // Collision edge detection
            collision_prev <= collision;
            if (collision && !collision_prev) begin
                in_collision_mode <= 1;
                collision_timer <= 0;
                redraw_counter <= 0;
            end
            
            // Track previous collision mode state
            in_collision_mode_prev <= in_collision_mode;
            
            // Update collision timer
            if (in_collision_mode) begin
                if (collision_timer < COLLISION_DURATION) begin
                    collision_timer <= collision_timer + 1;
                end else begin
                    in_collision_mode <= 0;
                    collision_timer <= 0;
                end
            end
            
            case (state)
                INIT: begin
                    player_x_pos <= lane_to_x(player_lane);
                    prev_x_pos <= lane_to_x(player_lane);
                    pixel_x <= 0;
                    pixel_y <= 0;
                    vga_write_reg <= 0;
                    next_state_after_draw <= IDLE;
                    state <= DRAW_INITIAL;
                end

                DRAW_INITIAL: begin
                    vga_x_reg <= player_x_pos + pixel_x;
                    vga_y_reg <= PLAYER_Y_POS + pixel_y;
                    vga_color_reg <= selected_rom_data;  // Use ROM data
                    vga_write_reg <= 1;
                   
                    if (pixel_x < PLAYER_WIDTH - 1)
                        pixel_x <= pixel_x + 1;
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < PLAYER_HEIGHT - 1)
                            pixel_y <= pixel_y + 1;
                        else begin
                            pixel_y <= 0;
                            vga_write_reg <= 0;
                            state <= next_state_after_draw;
                        end
                    end
                end

                IDLE: begin
                    vga_write_reg <= 0;
                    
                    // Detect when collision mode ends - trigger immediate redraw to normal color
                    if (in_collision_mode_prev && !in_collision_mode) begin
                        pixel_x <= 0;
                        pixel_y <= 0;
                        next_state_after_draw <= IDLE;
                        state <= DRAW;
                    end
                    // Redraw during collision mode
                    else if (in_collision_mode) begin
                        redraw_counter <= redraw_counter + 1;
                        if (redraw_counter >= REDRAW_INTERVAL) begin
                            redraw_counter <= 0;
                            pixel_x <= 0;
                            pixel_y <= 0;
                            next_state_after_draw <= IDLE;
                            state <= COLLISION_REDRAW;
                        end
                    end
                    
                    // Movement always allowed
                    if (!input_handled) begin
                        if (move_left && player_lane > 0) begin
                            prev_x_pos <= player_x_pos;
                            player_lane <= player_lane - 1;
                            player_x_pos <= lane_to_x(player_lane - 1);
                            pixel_x <= 0;
                            pixel_y <= 0;
                            input_handled <= 1;
                            next_state_after_draw <= IDLE;
                            state <= ERASE;
                        end
                        else if (move_right && player_lane < NUM_LANES - 1) begin
                            prev_x_pos <= player_x_pos;
                            player_lane <= player_lane + 1;
                            player_x_pos <= lane_to_x(player_lane + 1);
                            pixel_x <= 0;
                            pixel_y <= 0;
                            input_handled <= 1;
                            next_state_after_draw <= IDLE;
                            state <= ERASE;
                        end
                    end
                   
                    if (!move_left && !move_right)
                        input_handled <= 0;
                end

                ERASE: begin
                    vga_x_reg <= prev_x_pos + pixel_x;
                    vga_y_reg <= PLAYER_Y_POS + pixel_y;
                    vga_color_reg <= ERASE_COLOR;
                    vga_write_reg <= 1;
                   
                    if (pixel_x < PLAYER_WIDTH - 1)
                        pixel_x <= pixel_x + 1;
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < PLAYER_HEIGHT - 1)
                            pixel_y <= pixel_y + 1;
                        else begin
                            pixel_y <= 0;
                            vga_write_reg <= 0;
                            state <= DRAW;
                        end
                    end
                end

                DRAW: begin
                    vga_x_reg <= player_x_pos + pixel_x;
                    vga_y_reg <= PLAYER_Y_POS + pixel_y;
                    vga_color_reg <= selected_rom_data;  // Use ROM data
                    vga_write_reg <= 1;
                   
                    if (pixel_x < PLAYER_WIDTH - 1)
                        pixel_x <= pixel_x + 1;
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < PLAYER_HEIGHT - 1)
                            pixel_y <= pixel_y + 1;
                        else begin
                            pixel_y <= 0;
                            vga_write_reg <= 0;
                            state <= next_state_after_draw;
                        end
                    end
                end

                COLLISION_REDRAW: begin
                    vga_x_reg <= player_x_pos + pixel_x;
                    vga_y_reg <= PLAYER_Y_POS + pixel_y;
                    vga_color_reg <= selected_rom_data;  // Use invincible ROM
                    vga_write_reg <= 1;
                   
                    if (pixel_x < PLAYER_WIDTH - 1)
                        pixel_x <= pixel_x + 1;
                    else begin
                        pixel_x <= 0;
                        if (pixel_y < PLAYER_HEIGHT - 1)
                            pixel_y <= pixel_y + 1;
                        else begin
                            pixel_y <= 0;
                            vga_write_reg <= 0;
                            state <= next_state_after_draw;
                        end
                    end
                end

                default: state <= INIT;
            endcase
        end
    end

    assign VGA_x = vga_x_reg;
    assign VGA_y = vga_y_reg;
    assign VGA_color = vga_color_reg;
    assign VGA_write = vga_write_reg;
    assign is_erasing = (state == ERASE);
    assign is_drawing = (state == DRAW) || (state == DRAW_INITIAL) || (state == COLLISION_REDRAW);
    assign is_collision_mode = in_collision_mode;

endmodule