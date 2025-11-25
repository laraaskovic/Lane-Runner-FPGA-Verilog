`default_nettype none

module multi_obstacle(
    input wire Resetn,
    input wire Clock,
    input wire [2:0] player_lane,
    input wire player_is_collision_mode,
    output wire [9:0] VGA_x,
    output wire [8:0] VGA_y,
    output wire [8:0] VGA_color,
    output wire VGA_write,
    output reg collision,
    output reg score_increment,
    output wire is_erasing,
    output wire is_drawing
);

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter NUM_LANES = 5;
    parameter LANE_WIDTH = 80;
    parameter LANE_START_X = 120;

    parameter OBS_WIDTH = 60;
    parameter OBS_HEIGHT = 60;
    parameter MAX_OBSTACLES = 5;  

    parameter PLAYER_Y_POS = 360;
    parameter PLAYER_HEIGHT = 60;
    parameter SCORE_THRESHOLD = PLAYER_Y_POS + PLAYER_HEIGHT + 10;
    
    parameter SPAWN_Y_POS = -120; //fix this position later doesn't fix glitch
    parameter ERASE_COLOR = 9'b000_000_000;


    //states
    parameter IDLE = 3'd0;
    parameter ERASE_OBS = 3'd1;
    parameter MOVE_OBS = 3'd2;
    parameter DRAW_OBS = 3'd3;
    parameter CHECK_COLLISION = 3'd4;

    parameter INITIAL_SPEED_LIMIT = 23'd700_000;
    parameter MIN_SPEED_LIMIT = 23'd200_000; //max speen so that the game is playable still
    parameter SPEED_DECREMENT = 23'd50_000;
    
    //this is since we speed it up so we reduce spawn so that we dont have less obstacle on screen
    parameter INITIAL_SPAWN_INTERVAL = 27'd50_000_000;
    parameter MIN_SPAWN_INTERVAL = 27'd15_000_000;
    parameter SPAWN_DECREMENT = 27'd2_500_000;

    reg active0, active1, active2, active3, active4; //enables
    reg [2:0] obs_lane0, obs_lane1, obs_lane2, obs_lane3, obs_lane4;
    reg signed [9:0] obs_y0, obs_y1, obs_y2, obs_y3, obs_y4;
    reg [9:0] obs_x0, obs_x1, obs_x2, obs_x3, obs_x4;
    reg scored0, scored1, scored2, scored3, scored4;
    
    // Image type for each obstacle
    reg [1:0] obs_image0, obs_image1, obs_image2, obs_image3, obs_image4;

    reg [2:0] current_obs;  // Changed to 3 bits to handle 5 obstacles
    reg [5:0] pixel_x;
    reg [5:0] pixel_y;
    reg [2:0] state;

    reg [22:0] speed_counter;
    reg [22:0] current_speed_limit;
    reg [26:0] spawn_counter;
    reg [26:0] current_spawn_interval;

    reg [9:0] total_score;
    reg score_increment_prev;

    // LFSR for randomness
    reg [6:0] lfsr;
    wire [2:0] random_lane;
    wire [1:0] random_image;
    
    assign random_lane = (lfsr[4:0] % 5); //gives objects the lane to spawn in using previous logic
    assign random_image = lfsr[6:5];

    reg [9:0] vga_x_reg;
    reg [8:0] vga_y_reg;
    reg [8:0] vga_color_reg;
    reg vga_write_reg;

    // ROM 
    wire [11:0] rom_address;
    wire [8:0] rom_data_0, rom_data_1, rom_data_2, rom_data_3;
    
    reg [1:0] current_drawing_image;
    
    assign rom_address = (pixel_y * 60) + pixel_x; 
    
    //mux for getting the image selected
    wire [8:0] selected_rom_data;
    assign selected_rom_data = (current_drawing_image == 2'd0) ? rom_data_0 :
                                (current_drawing_image == 2'd1) ? rom_data_1 :
                                (current_drawing_image == 2'd2) ? rom_data_2 :
                                rom_data_3;

    // Instantiate 4 obstacle image ROMs
    obstacle_rom_0 OBS_ROM_0 (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_0)
    );
    
    obstacle_rom_1 OBS_ROM_1 (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_1)
    );
    
    obstacle_rom_2 OBS_ROM_2 (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_2)
    );
    
    obstacle_rom_3 OBS_ROM_3 (
        .address(rom_address),
        .clock(Clock),
        .q(rom_data_3)
    );

    //same as player fsm
    function [9:0] lane_to_x;
        input [2:0] lane;
        begin
            lane_to_x = LANE_START_X + (lane * LANE_WIDTH) + ((LANE_WIDTH - OBS_WIDTH) / 2);
        end
    endfunction

    always @(posedge Clock) 
    begin
        if (!Resetn) begin
            state <= IDLE;
            current_obs <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            speed_counter <= 0;
            spawn_counter <= 0;
            lfsr <= 7'b1010101;
            vga_write_reg <= 0;
            collision <= 0;
            score_increment <= 0;
            score_increment_prev <= 0;
            current_drawing_image <= 0;
            
            current_speed_limit <= INITIAL_SPEED_LIMIT;
            current_spawn_interval <= INITIAL_SPAWN_INTERVAL;
            total_score <= 0;

            active0 <= 0; obs_lane0 <= 0; obs_y0 <= SPAWN_Y_POS; obs_x0 <= 0; scored0 <= 0; obs_image0 <= 0;
            active1 <= 0; obs_lane1 <= 0; obs_y1 <= SPAWN_Y_POS; obs_x1 <= 0; scored1 <= 0; obs_image1 <= 0;
            active2 <= 0; obs_lane2 <= 0; obs_y2 <= SPAWN_Y_POS; obs_x2 <= 0; scored2 <= 0; obs_image2 <= 0;
            active3 <= 0; obs_lane3 <= 0; obs_y3 <= SPAWN_Y_POS; obs_x3 <= 0; scored3 <= 0; obs_image3 <= 0;
            active4 <= 0; obs_lane4 <= 0; obs_y4 <= SPAWN_Y_POS; obs_x4 <= 0; scored4 <= 0; obs_image4 <= 0;
        end
        
        else 
        begin
            score_increment <= 0;
            
            // Track score and adjust difficulty
            score_increment_prev <= score_increment;

            if (score_increment && !score_increment_prev) 
            begin 
                total_score <= total_score + 1;   //increase score
                
                //this checks if its a multiple of 5 to increase speed and reduce spawn
                if (total_score[2:0] == 3'b100 && current_speed_limit > MIN_SPEED_LIMIT)  
                begin
                    if (current_speed_limit > (MIN_SPEED_LIMIT + SPEED_DECREMENT))
                        current_speed_limit <= current_speed_limit - SPEED_DECREMENT;
                    else
                        current_speed_limit <= MIN_SPEED_LIMIT;
                end
                
                if (total_score[2:0] == 3'b100 && current_spawn_interval > MIN_SPAWN_INTERVAL) begin
                    if (current_spawn_interval > (MIN_SPAWN_INTERVAL + SPAWN_DECREMENT))
                        current_spawn_interval <= current_spawn_interval - SPAWN_DECREMENT;
                    else
                        current_spawn_interval <= MIN_SPAWN_INTERVAL;
                end
            end
            
            // Update LFSR
            if (state == IDLE && speed_counter == 0) begin
                lfsr <= {lfsr[5:0], lfsr[6] ^ lfsr[5]};
            end
            
            // Spawn new obstacles
            spawn_counter <= spawn_counter + 1;
            if (spawn_counter >= current_spawn_interval) 
            begin
                spawn_counter <= 0;

                if (!active0) 
                begin
                    active0 <= 1;
                    obs_lane0 <= random_lane;
                    obs_x0 <= lane_to_x(random_lane);
                    obs_y0 <= SPAWN_Y_POS;
                    scored0 <= 0;
                    obs_image0 <= random_image;
                end
                else if (!active1) 
                begin
                    active1 <= 1;
                    obs_lane1 <= random_lane;
                    obs_x1 <= lane_to_x(random_lane);
                    obs_y1 <= SPAWN_Y_POS;
                    scored1 <= 0;
                    obs_image1 <= random_image;
                end
                else if (!active2) 
                begin
                    active2 <= 1;
                    obs_lane2 <= random_lane;
                    obs_x2 <= lane_to_x(random_lane);
                    obs_y2 <= SPAWN_Y_POS;
                    scored2 <= 0;
                    obs_image2 <= random_image;
                end
                else if (!active3) 
                begin
                    active3 <= 1;
                    obs_lane3 <= random_lane;
                    obs_x3 <= lane_to_x(random_lane);
                    obs_y3 <= SPAWN_Y_POS;
                    scored3 <= 0;
                    obs_image3 <= random_image;
                end
                else if (!active4) 
                begin
                    active4 <= 1;
                    obs_lane4 <= random_lane;
                    obs_x4 <= lane_to_x(random_lane);
                    obs_y4 <= SPAWN_Y_POS;
                    scored4 <= 0;
                    obs_image4 <= random_image;
                end
            end

            case (state)
                IDLE: begin
                    vga_write_reg <= 0;

                    if (speed_counter < current_speed_limit)
                        speed_counter <= speed_counter + 1;
                    else begin
                        speed_counter <= 0;
                        current_obs <= 0;
                        state <= ERASE_OBS;
                    end
                end

                ERASE_OBS: begin
                    vga_write_reg <= 0;

                    // Only erase if obstacle is visible on screen
                    if (current_obs == 0) begin
                        if (active0 && obs_y0 >= 0)  // (Y >= 0 means at least partially visible)
                        begin
                            vga_x_reg <= obs_x0 + pixel_x;
                            vga_y_reg <= obs_y0[8:0] + pixel_y;
                            vga_color_reg <= ERASE_COLOR;
                            vga_write_reg <= 1;

                            //for loop to scan through the pixels
                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else 
                            begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 1;
                                end
                            end
                        end 
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 1;
                        end
                    end


                    //continue with same thing for other obstacles copy and paste!!!!!
                    else if (current_obs == 1) begin
                        if (active1 && obs_y1 >= 0) begin
                            vga_x_reg <= obs_x1 + pixel_x;
                            vga_y_reg <= obs_y1[8:0] + pixel_y;
                            vga_color_reg <= ERASE_COLOR;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 2;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 2;
                        end
                    end

                    else if (current_obs == 2) begin
                        if (active2 && obs_y2 >= 0) begin
                            vga_x_reg <= obs_x2 + pixel_x;
                            vga_y_reg <= obs_y2[8:0] + pixel_y;
                            vga_color_reg <= ERASE_COLOR;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 3;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 3;
                        end
                    end

                    else if (current_obs == 3) begin
                        if (active3 && obs_y3 >= 0) begin
                            vga_x_reg <= obs_x3 + pixel_x;
                            vga_y_reg <= obs_y3[8:0] + pixel_y;
                            vga_color_reg <= ERASE_COLOR;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 4;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 4;
                        end
                    end

                    // NEW: Handle 5th obstacle
                    else if (current_obs == 4) begin
                        if (active4 && obs_y4 >= 0) begin
                            vga_x_reg <= obs_x4 + pixel_x;
                            vga_y_reg <= obs_y4[8:0] + pixel_y;
                            vga_color_reg <= ERASE_COLOR;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    state <= MOVE_OBS;
                                    current_obs <= 0;
                                end
                            end
                        end
                        else begin
                            state <= MOVE_OBS;
                            current_obs <= 0;
                        end
                    end
                end

                MOVE_OBS: begin
                    vga_write_reg <= 0;

                    if (current_obs == 0) begin
                        if (active0) begin
                            if (obs_y0 >= YSCREEN) begin
                                active0 <= 0;
                                scored0 <= 0;
                            end
                            else begin
                                obs_y0 <= obs_y0 + 2;
                                if (!scored0 && obs_y0 >= SCORE_THRESHOLD) begin
                                    score_increment <= 1;
                                    scored0 <= 1;
                                end
                            end
                        end
                        current_obs <= 1;
                    end
                    else if (current_obs == 1) begin
                        if (active1) begin
                            if (obs_y1 >= YSCREEN) begin
                                active1 <= 0;
                                scored1 <= 0;
                            end
                            else begin
                                obs_y1 <= obs_y1 + 2;
                                if (!scored1 && obs_y1 >= SCORE_THRESHOLD) begin
                                    score_increment <= 1;
                                    scored1 <= 1;
                                end
                            end
                        end
                        current_obs <= 2;
                    end
                    else if (current_obs == 2) begin
                        if (active2) begin
                            if (obs_y2 >= YSCREEN) begin
                                active2 <= 0;
                                scored2 <= 0;
                            end
                            else begin
                                obs_y2 <= obs_y2 + 2;
                                if (!scored2 && obs_y2 >= SCORE_THRESHOLD) begin
                                    score_increment <= 1;
                                    scored2 <= 1;
                                end
                            end
                        end
                        current_obs <= 3;
                    end
                    else if (current_obs == 3) begin
                        if (active3) begin
                            if (obs_y3 >= YSCREEN) begin
                                active3 <= 0;
                                scored3 <= 0;
                            end
                            else begin
                                obs_y3 <= obs_y3 + 2;
                                if (!scored3 && obs_y3 >= SCORE_THRESHOLD) begin
                                    score_increment <= 1;
                                    scored3 <= 1;
                                end
                            end
                        end
                        current_obs <= 4;
                    end
                    else if (current_obs == 4) begin
                        if (active4) begin
                            if (obs_y4 >= YSCREEN) begin
                                active4 <= 0;
                                scored4 <= 0;
                            end
                            else begin
                                obs_y4 <= obs_y4 + 2;
                                if (!scored4 && obs_y4 >= SCORE_THRESHOLD) begin
                                    score_increment <= 1;
                                    scored4 <= 1;
                                end
                            end
                        end
                        current_obs <= 0;
                        state <= DRAW_OBS;
                    end
                end

                DRAW_OBS: begin
                    // Only draw if obstacle is visible (y >= 0)
                    if (current_obs == 0) begin
                        if (active0 && obs_y0 >= 0 && obs_y0 < YSCREEN) begin
                            current_drawing_image <= obs_image0;
                            vga_x_reg <= obs_x0 + pixel_x;
                            vga_y_reg <= obs_y0[8:0] + pixel_y;
                            vga_color_reg <= selected_rom_data;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 1;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 1;
                        end
                    end

                    else if (current_obs == 1) begin
                        if (active1 && obs_y1 >= 0 && obs_y1 < YSCREEN) begin
                            current_drawing_image <= obs_image1;
                            vga_x_reg <= obs_x1 + pixel_x;
                            vga_y_reg <= obs_y1[8:0] + pixel_y;
                            vga_color_reg <= selected_rom_data;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 2;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 2;
                        end
                    end

                    else if (current_obs == 2) begin
                        if (active2 && obs_y2 >= 0 && obs_y2 < YSCREEN) begin
                            current_drawing_image <= obs_image2;
                            vga_x_reg <= obs_x2 + pixel_x;
                            vga_y_reg <= obs_y2[8:0] + pixel_y;
                            vga_color_reg <= selected_rom_data;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 3;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 3;
                        end
                    end

                    else if (current_obs == 3) begin
                        if (active3 && obs_y3 >= 0 && obs_y3 < YSCREEN) begin
                            current_drawing_image <= obs_image3;
                            vga_x_reg <= obs_x3 + pixel_x;
                            vga_y_reg <= obs_y3[8:0] + pixel_y;
                            vga_color_reg <= selected_rom_data;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    current_obs <= 4;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            current_obs <= 4;
                        end
                    end

                    // NEW: Draw 5th obstacle
                    else if (current_obs == 4) begin
                        if (active4 && obs_y4 >= 0 && obs_y4 < YSCREEN) begin
                            current_drawing_image <= obs_image4;
                            vga_x_reg <= obs_x4 + pixel_x;
                            vga_y_reg <= obs_y4[8:0] + pixel_y;
                            vga_color_reg <= selected_rom_data;
                            vga_write_reg <= 1;

                            if (pixel_x < OBS_WIDTH - 1)
                                pixel_x <= pixel_x + 1;
                            else begin
                                pixel_x <= 0;
                                if (pixel_y < OBS_HEIGHT - 1)
                                    pixel_y <= pixel_y + 1;
                                else begin
                                    pixel_y <= 0;
                                    vga_write_reg <= 0;
                                    state <= CHECK_COLLISION;
                                end
                            end
                        end
                        else begin
                            pixel_x <= 0;
                            pixel_y <= 0;
                            state <= CHECK_COLLISION;
                        end
                    end
                end

                CHECK_COLLISION: 
                begin
                    collision <= 0;

                    if (!player_is_collision_mode) begin
                        if (active0 && obs_lane0 == player_lane &&
                            obs_y0 >= (PLAYER_Y_POS - OBS_HEIGHT) &&
                            obs_y0 <= (PLAYER_Y_POS + PLAYER_HEIGHT))
                            collision <= 1;

                        if (active1 && obs_lane1 == player_lane &&
                            obs_y1 >= (PLAYER_Y_POS - OBS_HEIGHT) &&
                            obs_y1 <= (PLAYER_Y_POS + PLAYER_HEIGHT))
                            collision <= 1;

                        if (active2 && obs_lane2 == player_lane &&
                            obs_y2 >= (PLAYER_Y_POS - OBS_HEIGHT) &&
                            obs_y2 <= (PLAYER_Y_POS + PLAYER_HEIGHT))
                            collision <= 1;

                        if (active3 && obs_lane3 == player_lane &&
                            obs_y3 >= (PLAYER_Y_POS - OBS_HEIGHT) &&
                            obs_y3 <= (PLAYER_Y_POS + PLAYER_HEIGHT))
                            collision <= 1;

                        // NEW: Check collision for 5th obstacle
                        if (active4 && obs_lane4 == player_lane &&
                            obs_y4 >= (PLAYER_Y_POS - OBS_HEIGHT) &&
                            obs_y4 <= (PLAYER_Y_POS + PLAYER_HEIGHT))
                            collision <= 1;
                    end

                    state <= IDLE;
                end
            endcase
        end
    end

    assign VGA_x = vga_x_reg;
    assign VGA_y = vga_y_reg;
    assign VGA_color = vga_color_reg;
    assign VGA_write = vga_write_reg;
    assign is_erasing = (state == ERASE_OBS);
    assign is_drawing = (state == DRAW_OBS);

endmodule