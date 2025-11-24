# Lane Runner 🎮

A lane-based runner game implemented in Verilog for FPGA (Altera DE1-SoC), featuring progressive difficulty, multiple lives, and VGA output. Navigate through five lanes to dodge obstacles and rack up points!

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Hardware Requirements](#hardware-requirements)
- [Game Controls](#game-controls)
- [File Structure](#file-structure)
- [Module Documentation](#module-documentation)
- [Game Mechanics](#game-mechanics)
- [Display Information](#display-information)
- [How to Build and Run](#how-to-build-and-run)
- [Technical Details](#technical-details)
- [Customization](#customization)

## 🎯 Overview

Lane Runner is a fast-paced arcade-style game where players navigate a character through five vertical lanes while avoiding incoming obstacles. The game features progressive difficulty scaling, a lives system, and multiple end-game conditions (win/lose). Built entirely in Verilog for FPGA hardware, it demonstrates complex state machine design, VGA graphics rendering, and real-time game logic.

## ✨ Features

- **5-Lane Gameplay**: Navigate through five distinct lanes with smooth transitions
- **Progressive Difficulty**: Speed and spawn rate increase as your score climbs
- **Lives System**: Start with 3 lives, game over when all lives are lost
- **Win Condition**: Reach a score of 333 to win the game
- **Multiple Input Methods**: 
  - Push buttons (KEY[0], KEY[1])
  - PS/2 Keyboard (Arrow keys)
- **Visual Variety**: 4 different obstacle sprites loaded from ROM
- **Screen Management**:
  - Title screen ("LANE RUNNER")
  - Win screen ("WIN!!")
  - Lose screen ("LOSER")
- **Real-time Feedback**:
  - Score display on 7-segment displays (HEX0-HEX2)
  - Lives display on 7-segment display (HEX5)
  - LED indicators for game state
- **Collision Detection**: Red flash effect on collision with invincibility period
- **Dynamic Rendering**: Efficient VGA priority-based arbitration system

## 🔧 Hardware Requirements

- **FPGA Board**: Altera DE1-SoC
- **Display**: VGA monitor (640x480 resolution @ 60Hz)
- **Input Devices**:
  - On-board push buttons (KEY[0-3])
  - On-board switches (SW[9])
  - PS/2 Keyboard (optional)
- **Clock**: 50 MHz system clock (CLOCK_50)

## 🎮 Game Controls

### Input Controls
| Control | Function |
|---------|----------|
| **KEY[0]** or **Right Arrow** | Move player right |
| **KEY[1]** or **Left Arrow** | Move player left |
| **KEY[3]** | Start game from title screen |
| **KEY[2]** | Restart game after game over / Clear end screen |
| **SW[9]** | Global reset (active high) |

### LED Indicators
| LED | Indicates |
|-----|-----------|
| **LEDR[2:0]** | Current player lane (0-4) |
| **LEDR[3]** | Collision detected |
| **LEDR[4]** | Game over status |
| **LEDR[6:5]** | Current lives remaining |
| **LEDR[7]** | Screen active (title/win/lose) |
| **LEDR[8]** | Win condition reached |
| **LEDR[9]** | Player in collision mode (red flash) |

### 7-Segment Displays
| Display | Shows |
|---------|-------|
| **HEX2** | Score hundreds digit |
| **HEX1** | Score tens digit |
| **HEX0** | Score ones digit |
| **HEX5** | Lives remaining (0-3) |

## 📁 File Structure

### Core Modules

#### `lane_runner_top.v`
**Top-level module** - System integration and VGA arbiter
- Instantiates all sub-modules
- Manages VGA output priority and arbitration
- Coordinates game state transitions
- Handles input synchronization
- Contains keyboard decoder and sync modules
- Implements screen erase control logic

**Key Features:**
- VGA priority system (title → eraser → end screens → player → obstacles)
- Edge detection for state transitions
- Manual clear functionality for end screens
- End screen suppression logic

#### `multi_obstacle.v`
**Obstacle management system**
- Manages up to 5 simultaneous obstacles
- Progressive difficulty scaling (speed and spawn rate)
- LFSR-based random lane selection
- 4 different obstacle sprites from ROM
- Collision detection with player
- Score increment on successful dodge
- Dynamic obstacle spawning

**Key Parameters:**
- Initial speed: 700,000 clock cycles
- Minimum speed: 200,000 clock cycles
- Speed decreases every 5 points
- 5 lanes, 60×60 pixel obstacles
- Spawn position: -120 pixels (off-screen)

#### `score_counter.v`
**Score tracking and display**
- Tracks player score (0-999)
- Converts binary score to decimal digits
- Drives three 7-segment displays
- Edge detection for score increment
- Includes hex decoder module

**Features:**
- Automatic decimal conversion
- Maximum score capping at 999
- Real-time display updates

#### `game_over_handler.v`
**Lives system and game over logic**
- Manages 3-life system
- Collision detection and life decrement
- Game over state when lives reach 0
- Restart functionality via KEY[2]
- Score reset signal generation
- Lives display on HEX5

**Mechanics:**
- Start with 3 lives
- Lose 1 life per collision
- Game over at 0 lives
- Restart resets lives and score

#### `title_screen.v`
**Title screen display**
- Draws "LANE RUNNER" text vertically
- One letter per lane (L-A-N-E-R)
- Wait for KEY[3] to start
- Clean erase before game start
- Custom 5×7 bitmap fonts scaled to 40×50 pixels

**Display:**
- Yellow text (RGB: 111_111_000)
- Centered in lanes
- Vertical letter arrangement

#### `lose_screen.v`
**Game over screen display**
- Draws "LOSER" text vertically
- One letter per lane (L-O-S-E-R)
- Red text for emphasis
- Triggered by game_over flag
- Custom 5×7 bitmap fonts

**Display:**
- Red text (RGB: 111_000_000)
- Centered in lanes
- Appears after screen erase

#### `screen_eraser.v`
**Screen management utility**
- Erases only the 5 playable lanes
- Preserves background in gaps
- Triggered before/after game states
- Efficient scan-based erasing
- Priority over most rendering

**Operation:**
- Erases 60-pixel wide lanes
- Skips 20-pixel gaps
- Black fill (RGB: 000_000_000)
- Signals completion when done

#### `PS2_Controller.v`
**PS/2 keyboard interface** (Altera IP)
- Bidirectional PS/2 communication
- Keyboard initialization
- Scan code reception
- Data validation and timing
- Error handling

**Features:**
- Standard PS/2 protocol
- 8-bit data reception
- Clock synchronization
- Command transmission support

### Additional Modules

#### `player_object` (referenced, not provided)
- Player character rendering
- Lane position management
- Movement control
- Collision mode (red flash)
- Erase/draw state management

#### `win_screen` (referenced, not provided)
- Win condition display
- "WIN!!" text rendering
- Similar structure to lose_screen

#### `vga_adapter` (referenced, not provided)
- VGA signal generation
- Color buffer management
- H-sync and V-sync timing
- 640×480 @ 60Hz output
- Background image loading

#### `obstacle_rom_0/1/2/3` (referenced, not provided)
- Sprite data storage
- 60×60 pixel images
- 9-bit color depth
- ROM-based lookup tables

## 🎲 Game Mechanics

### Gameplay Loop

1. **Title Screen**: Display "LANE RUNNER" and wait for start
2. **Game Active**: 
   - Player dodges obstacles
   - Score increases for each avoided obstacle
   - Lives decrease on collision
   - Difficulty progressively increases
3. **End Conditions**:
   - **Win**: Reach score of 333
   - **Lose**: Run out of lives (0 remaining)
4. **End Screen**: Display win/lose message
5. **Restart**: Press KEY[2] to play again

### Scoring System

- **+1 point** for each obstacle that passes below the player
- Obstacles score only once (tracked per obstacle)
- Score threshold: Player Y + Height + 10 pixels
- Maximum score: 999 (display limit)
- **Win at 333 points**

### Difficulty Scaling

**Speed Increase:**
- Every 5 points, obstacle speed increases
- Speed limit decreases by 50,000 clock cycles
- Minimum speed: 200,000 cycles (2.5× faster than start)

**Spawn Rate Increase:**
- Every 5 points, spawn interval decreases
- Interval decreases by 2,500,000 cycles
- Minimum interval: 15,000,000 cycles (3.3× faster spawning)

### Collision System

- Collision detected when obstacle overlaps player vertically
- Must be in the same lane
- **Grace Period**: After collision, player enters "collision mode"
  - Player flashes red for brief invincibility
  - Prevents multiple life losses from same obstacle
  - Collision detection disabled during red flash

### Lane System

- **5 lanes** across the screen
- **Lane 0-4** (leftmost to rightmost)
- Each lane: 80 pixels wide total
  - 60 pixels playable area
  - 20 pixels for gaps (10px each side)
- Lane start X: 120 pixels
- Total play area: 400 pixels (120-520 X)

## 📊 Display Information

### Screen Layout

```
┌─────────────────────────────────────────┐
│  [Background Image - 640×480]           │
│                                         │
│  ┌─┬──────┬─┬──────┬─┬──────┬─┬──────┬─┬──────┬─┐
│  │ │ L0   │ │ L1   │ │ L2   │ │ L3   │ │ L4   │ │
│  │ │      │ │      │ │      │ │      │ │      │ │
│  │ │ [OBS]│ │      │ │ [OBS]│ │      │ │      │ │
│  │ │      │ │      │ │      │ │ [OBS]│ │      │ │
│  │ │      │ │      │ │      │ │      │ │      │ │
│  │ │ [PLR]│ │      │ │      │ │      │ │      │ │
│  └─┴──────┴─┴──────┴─┴──────┴─┴──────┴─┴──────┴─┘
│                                         │
└─────────────────────────────────────────┘
  120px           Lanes (80px each)        520px
```

### VGA Priority System

Rendering priority (highest to lowest):

1. **Title Screen** - Initial game screen
2. **Screen Eraser** - Clears lanes for transitions
3. **Lose Screen** - Game over display (when not suppressed)
4. **Win Screen** - Victory display (when not suppressed)
5. **Player (Collision Mode)** - Red flash overlay
6. **Player (Erase)** - Clear old player position
7. **Player (Draw)** - Normal player rendering
8. **Obstacles (Draw)** - Obstacle sprites
9. **Obstacles (Erase)** - Clear old obstacle positions

### Color Scheme

| Element | Color | RGB (3-3-3) |
|---------|-------|-------------|
| Background | From MIF file | Variable |
| Player (Normal) | From player_object | Variable |
| Player (Collision) | Red | 111_000_000 |
| Obstacles | From ROM (4 variants) | Variable |
| Title Text | Yellow | 111_111_000 |
| Win Text | Green (assumed) | Variable |
| Lose Text | Red | 111_000_000 |
| Erase/Black | Black | 000_000_000 |

## 🚀 How to Build and Run

### Prerequisites

1. **Quartus Prime** (Intel/Altera) - For synthesis and programming
2. **ModelSim** (optional) - For simulation
3. **DE1-SoC Board** - Target hardware
4. **VGA Monitor** - For display output
5. **PS/2 Keyboard** (optional) - For keyboard controls

### Required Files

Ensure you have all these files:
- `lane_runner_top.v` ✓
- `multi_obstacle.v` ✓
- `score_counter.v` ✓
- `game_over_handler.v` ✓
- `title_screen.v` ✓
- `lose_screen.v` ✓
- `screen_eraser.v` ✓
- `PS2_Controller.v` ✓
- `player_object.v` (not provided - implement separately)
- `win_screen.v` (not provided - similar to lose_screen)
- `vga_adapter.v` (Altera University Program IP)
- `obstacle_rom_0.v` through `obstacle_rom_3.v` (ROM files)
- `image.colour.mif` (Background image)
- Additional support files for PS/2 controller

### Building the Project

1. **Create New Project**:
   ```
   - Open Quartus Prime
   - File → New Project Wizard
   - Select DE1-SoC device (Cyclone V)
   - Add all .v files to project
   ```

2. **Add Pin Assignments**:
   - Import DE1-SoC pin assignments (.qsf file)
   - Or manually assign pins for:
     - CLOCK_50
     - SW[9:0]
     - KEY[3:0]
     - LEDR[9:0]
     - HEX5, HEX2, HEX1, HEX0
     - VGA signals (R, G, B, HS, VS, etc.)
     - PS2_CLK, PS2_DAT

3. **Configure Memory Files**:
   - Place `image.colour.mif` in project directory
   - Generate ROM .mif files for obstacle sprites
   - Ensure ROM instances match memory initialization files

4. **Compile**:
   ```
   - Processing → Start Compilation
   - Wait for successful compilation
   - Check for timing violations
   ```

5. **Program FPGA**:
   ```
   - Tools → Programmer
   - Load .sof file
   - Connect USB-Blaster
   - Click "Start"
   ```

### Running the Game

1. **Power On**:
   - Connect VGA monitor
   - Connect PS/2 keyboard (optional)
   - Power on DE1-SoC board

2. **Initialize**:
   - Set SW[9] = OFF (reset low)
   - Set SW[9] = ON briefly, then OFF (activate reset)
   - Title screen should appear

3. **Start Game**:
   - Press KEY[3] to start
   - Title erases and game begins

4. **Play**:
   - Use KEY[0]/KEY[1] or arrow keys to move
   - Avoid obstacles
   - Watch score on HEX displays

5. **End Game**:
   - Win: Reach 333 points
   - Lose: Run out of lives
   - Press KEY[2] to restart

## 🔍 Technical Details

### Timing Specifications

| Parameter | Value |
|-----------|-------|
| System Clock | 50 MHz (20 ns period) |
| VGA Refresh | 60 Hz |
| VGA Resolution | 640×480 pixels |
| Color Depth | 9 bits (3R-3G-3B) |
| Initial Obstacle Speed | 700,000 cycles (~14 ms) |
| Min Obstacle Speed | 200,000 cycles (~4 ms) |
| Initial Spawn Interval | 50M cycles (~1 second) |
| Min Spawn Interval | 15M cycles (~0.3 seconds) |

### Memory Requirements

- **VGA Frame Buffer**: Managed by vga_adapter
- **Obstacle ROMs**: 4 × 3600 pixels × 9 bits = 16.2 KB
- **Background Image**: 640 × 480 × 9 bits = 2.7 Mbit
- **State Registers**: Minimal (~1 KB logic)

### FPGA Resource Usage (Estimated)

- **Logic Elements**: ~5,000-8,000 LEs
- **Memory Bits**: ~2.8 Mbits (mostly for images)
- **PLLs**: 1 (if used for VGA clock)
- **Pins**: ~50 I/O pins

### State Machines

The design contains multiple FSMs:

1. **Game State (lane_runner_top)**:
   - Title → Playing → Win/Lose → Restart

2. **Obstacle FSM (multi_obstacle)**:
   - IDLE → ERASE_OBS → MOVE_OBS → DRAW_OBS → CHECK_COLLISION

3. **Title Screen FSM**:
   - IDLE → DRAW_TITLE → WAIT_START → ERASE_TITLE → DONE

4. **Screen Eraser FSM**:
   - IDLE → ERASING → DONE

5. **End Screen FSMs** (Lose/Win):
   - IDLE → DRAWING → DONE

### Key Design Patterns

- **Double-Buffering**: VGA adapter handles frame buffering
- **Edge Detection**: Registers previous signal states to detect transitions
- **Priority Arbitration**: VGA signals multiplexed by priority
- **Debouncing**: Sync modules provide button debouncing
- **LFSR**: Pseudo-random number generation for obstacle lanes
- **ROM Lookup**: Sprite data stored in on-chip memory

## ⚙️ Customization

### Difficulty Tuning

In `multi_obstacle.v`, adjust:

```verilog
parameter INITIAL_SPEED_LIMIT = 23'd700_000;    // Starting speed
parameter MIN_SPEED_LIMIT = 23'd200_000;        // Max speed
parameter SPEED_DECREMENT = 23'd50_000;         // Speed increase rate

parameter INITIAL_SPAWN_INTERVAL = 27'd50_000_000;  // Starting spawn
parameter MIN_SPAWN_INTERVAL = 27'd15_000_000;      // Max spawn rate
parameter SPAWN_DECREMENT = 27'd2_500_000;          // Spawn increase rate
```

### Win Condition

In `lane_runner_top.v`:

```verilog
assign win_condition = (score == 10'd333);  // Change target score
```

### Number of Obstacles

In `multi_obstacle.v`:

```verilog
parameter MAX_OBSTACLES = 5;  // Increase/decrease simultaneous obstacles
```

### Number of Lives

In `game_over_handler.v`:

```verilog
lives <= 2'd3;  // Starting lives (0-3 possible with 2-bit register)
```

### Lane Configuration

In multiple files, adjust:

```verilog
parameter NUM_LANES = 5;        // Number of lanes
parameter LANE_WIDTH = 80;      // Total lane width
parameter LANE_START_X = 120;   // Leftmost lane position
```

### Colors

Modify color parameters in each module:

```verilog
parameter TITLE_COLOR = 9'b111_111_000;  // Yellow
parameter LOSE_COLOR = 9'b111_000_000;   // Red
parameter ERASE_COLOR = 9'b000_000_000;  // Black
```

### Obstacle Sprites

Replace the ROM files (`obstacle_rom_0.v` through `obstacle_rom_3.v`) with custom sprite data. Each sprite should be 60×60 pixels with 9-bit color.

### Background Image

Replace `image.colour.mif` with a custom 640×480 image in MIF format. Use Altera's image converter tool to generate MIF files from images.

## 📝 Notes

- The game uses active-low reset (SW[9])
- All push buttons are active-low (KEY[n])
- VGA signals use positive polarity sync
- PS/2 keyboard is optional; buttons work standalone
- Background image provides aesthetic appeal but isn't required for gameplay
- Obstacle spawning uses LFSR for randomness (not cryptographically secure)
- Collision detection has a grace period to prevent unfair multi-hits

## 🐛 Troubleshooting

**No VGA Display:**
- Check VGA cable connection
- Verify pin assignments match DE1-SoC
- Ensure vga_adapter is properly instantiated

**Game Won't Start:**
- Check SW[9] is low after reset
- Verify KEY[3] is connected and working
- Check title_screen module completion signal

**Obstacles Not Appearing:**
- Verify obstacle ROM files are included
- Check ROM initialization files (.mif) exist
- Ensure multi_obstacle module is enabled

**Keyboard Not Working:**
- Check PS/2 cable is connected
- Verify PS2_CLK and PS2_DAT pins
- Test with push buttons as alternative

**Timing Violations:**
- Enable timing-driven compilation
- Add timing constraints (.sdc file)
- Consider clock domain crossing issues

## 🎓 Learning Resources

This project demonstrates:
- Complex state machine design
- VGA video signal generation
- Memory-mapped graphics rendering
- Real-time game logic in hardware
- Resource arbitration and priority systems
- Synchronous digital design principles
- FPGA peripheral interfacing (PS/2, VGA)

## 📜 License

This project is provided as-is for educational purposes. Feel free to modify and extend for learning and non-commercial use.

## 🙏 Acknowledgments

- Altera/Intel for DE1-SoC board and IP cores
- University Program VGA adapter
- PS/2 controller from Altera UP libraries

---

**Enjoy playing Lane Runner! 🎮🏃‍♂️**

*For questions or issues, please refer to the module documentation above or consult the Verilog source code comments.*
