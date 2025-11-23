`default_nettype none

module screen_eraser(
    input wire Resetn,      
    input wire Clock,
    input wire enable,         
    
    // Erase control outputs
    output reg erase_active,     
    output wire [9:0] erase_x,
    output wire [8:0] erase_y,
    output wire [8:0] erase_color,
    output wire erase_write
);
    // Screen parameters
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;
    
    // Lane configuration
    parameter NUM_LANES = 5;
    parameter LANE_WIDTH = 80;      
    parameter LANE_START_X = 120;
    parameter PLAYABLE_WIDTH = 60;  // Only erase the 60px playable area
    parameter GAP_SIZE = 20;        // 20px gap (10px on each side)
    
    parameter ERASE_START_Y = 0;
    parameter ERASE_END_Y = 479;
    
    parameter BLACK = 9'b000_000_000;
    
    // States
    parameter IDLE = 2'd0;
    parameter ERASING = 2'd1;
    parameter DONE = 2'd2;
    
    reg [1:0] state;
    
    // Current lane being erased (0-4)
    reg [2:0] current_lane;
    
    // Position within current lane
    reg [5:0] lane_pixel_x; 
    reg [8:0] erase_y_reg;
    
    reg [9:0] erase_x_reg;
    reg erase_write_reg;
    
    reg prev_enable;
    wire enable_trigger;
    assign enable_trigger = !prev_enable && enable;
    
    // Calculate actual X position from lane and pixel offset
    // Each lane starts at: LANE_START_X + (lane * LANE_WIDTH) + (GAP_SIZE/2)
    wire [9:0] lane_start_x;
    assign lane_start_x = LANE_START_X + (current_lane * LANE_WIDTH) + (GAP_SIZE / 2);
    
    // Main FSM
    always @(posedge Clock) begin
        prev_enable <= enable;
        
        if (!Resetn) begin
            // During reset - go to idle
            state <= IDLE;
            current_lane <= 0;
            lane_pixel_x <= 0;
            erase_y_reg <= ERASE_START_Y;
            erase_write_reg <= 0;
            erase_active <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (enable_trigger) begin
                        // Enable signal triggered - start erasing
                        erase_active <= 1;
                        current_lane <= 0;
                        lane_pixel_x <= 0;
                        erase_y_reg <= ERASE_START_Y;
                        erase_write_reg <= 1;
                        state <= ERASING;
                    end
                    else begin
                        erase_active <= 0;
                        erase_write_reg <= 0;
                    end
                end
                
                ERASING: begin
                    erase_x_reg <= lane_start_x + lane_pixel_x;
                    erase_write_reg <= 1;
                    
                    // Move across current lane
                    if (lane_pixel_x < PLAYABLE_WIDTH - 1) begin
                        lane_pixel_x <= lane_pixel_x + 1;
                    end
                    else begin
                        // Finished one row of current lane
                        lane_pixel_x <= 0;
                        
                        if (erase_y_reg < ERASE_END_Y) begin
                            // Move to next row
                            erase_y_reg <= erase_y_reg + 1;
                        end
                        else begin
                            // Finished entire lane
                            erase_y_reg <= ERASE_START_Y;
                            
                            if (current_lane < NUM_LANES - 1) begin
                                // Move to next lane
                                current_lane <= current_lane + 1;
                            end
                            else begin
                                // Done erasing all lanes
                                erase_write_reg <= 0;
                                erase_active <= 0;
                                state <= DONE;
                            end
                        end
                    end
                end
                
                DONE: begin
                    erase_active <= 0;
                    erase_write_reg <= 0;
                    if (!enable) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Output assignments
    assign erase_x = erase_x_reg;
    assign erase_y = erase_y_reg;
    assign erase_color = BLACK;
    assign erase_write = erase_write_reg;
endmodule
