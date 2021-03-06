//============================================================================
//  DoDonPachi for MiSTer.
//  Copyright (c) 2019 Rick Wertenbroek
//  Copyright (c) 2020 Josh Bassett
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu (
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [45:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  output  [7:0] VIDEO_ARX,
  output  [7:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler

  // Use framebuffer from DDRAM (USE_FB=1 in qsf)
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  // I/O board button press simulation (active high)
  // b[1]: user button
  // b[0]: osd button
  output  [1:0] BUTTONS,

  input         CLK_AUDIO, // 24.576 MHz
  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
output	USER_OSD,
output	[1:0] USER_MODE,
input	[7:0] USER_IN,
output	[7:0] USER_OUT
);

assign AUDIO_S   = 1;
assign AUDIO_MIX = 0;

assign BUTTONS = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : status[2] ? 8'd3 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : status[2] ? 8'd4 : 8'd3;

// Required for BlisSTer
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[30],status[31],status[29]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];


`include "build_id.v"
localparam CONF_STR = {
  "cave;;",
  "OOR,CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
  "OSV,CRT V adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
  "D0O1,Aspect Ratio,4:3,16:9;",
  "D0O2,Orientation,Horizontal,Vertical;",
  "O3,Flip Screen,Off,On;",
  "O46,Scandoubler,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
  "-;",
  "P1,Advanced;",
  "P1-;",
  "P1O7,Refresh Rate,57.5Hz,60Hz;",
  "d1P1O8,ROM Storage,SDRAM,DDR3;",
  "P2,Debug;",
  "P2-;",
  "P2OA,Sprites,On,Off;",
  "P2OB,Layer 0,On,Off;",
  "P2OC,Layer 1,On,Off;",
  "P2OD,Layer 2,On,Off;",
  "-;",
  "OUV,UserIO Joystick,Off,DB9MD,DB15 ;",
  "OT,UserIO Players, 1 Player,2 Players;",
  "-;",
  "R0,Reset;",
  "J1,B0,B1,B2,Start,Coin,Pause;",
  "V,v",`BUILD_DATE," - Made with love by nullobject.;"
};

////////////////////////////////////////////////////////////////////////////////
// CLOCK AND RESET
////////////////////////////////////////////////////////////////////////////////

wire locked;
wire clk_sys, clk_sdram, clk_video, clk_cpu;
reg  reset_pll = 0;
wire reset_sys = RESET | ~locked;
reg  reset_sys_0 = 1;
reg  reset_sys_1 = 1;
wire reset_video = RESET | ~locked;
reg  reset_video_0 = 1;
reg  reset_video_1 = 1;
wire reset_cpu = RESET | status[0] | buttons[1] | ~locked;
reg  reset_cpu_0 = 1;
reg  reset_cpu_1 = 1;

// Resets the PLL if it loses lock
always @(posedge clk_sys or posedge RESET) begin
  reg last_locked;
  reg [7:0] rst_cnt;

  if (RESET) begin
    reset_pll <= 0;
    rst_cnt <= 8'h00;
  end else begin
    last_locked <= locked;
    if (last_locked && !locked) begin
      rst_cnt <= 8'hff; // keep reset high for 256 cycles
      reset_pll <= 1;
    end else begin
      if (rst_cnt != 8'h00)
        rst_cnt <= rst_cnt - 8'h1;
      else
        reset_pll <= 0;
    end
  end
end

pll pll (
  .refclk(CLK_50M),
  .rst(reset_pll),
  .locked(locked),
  .outclk_0(clk_sys),
  .outclk_1(clk_sdram),
  .outclk_2(clk_video),
  .outclk_3(clk_cpu)
);

assign DDRAM_CLK = clk_sys;
assign SDRAM_CLK = clk_sdram;

always_ff @(posedge clk_sys) begin
  reset_sys_0 <= reset_sys;
  reset_sys_1 <= reset_sys_0;
end

always_ff @(posedge clk_video) begin
  reset_video_0 <= reset_video;
  reset_video_1 <= reset_video_0;
end

always_ff @(posedge clk_cpu) begin
  reset_cpu_0 <= reset_cpu;
  reset_cpu_1 <= reset_cpu_0;
end

////////////////////////////////////////////////////////////////////////////////
// HPS IO
////////////////////////////////////////////////////////////////////////////////

wire  [1:0] buttons;
wire [31:0] status;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire        direct_video;
wire [15:0] sdram_sz;

wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire        ioctl_wait;
wire        ioctl_download;
wire  [7:0] ioctl_index;

wire [10:0] ps2_key;
wire [10:0] joystick_0_USB, joystick_1_USB;

wire sdram_available = |sdram_sz[1:0];

// PA ST F3 F2 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? {joydb_2[9],joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[10],joydb_1[6:0]} : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? {joydb_2[10],joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[9],joydb_2[6:0]} : joydb_1ena ? joystick_0_USB : joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io (
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),

  .conf_str(CONF_STR),

  .buttons(buttons),
  .status(status),
  .status_menumask({sdram_available, direct_video}),
  .forced_scandoubler(forced_scandoubler),
  .gamma_bus(gamma_bus),
  .direct_video(direct_video),
  .sdram_sz(sdram_sz),

  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_dout),
  .ioctl_wr(ioctl_wr),
  .ioctl_wait(ioctl_wait),
  .ioctl_download(ioctl_download),
  .ioctl_index(ioctl_index),

  .joystick_0(joystick_0_USB),
  .joystick_1(joystick_1_USB),
  .joy_raw(joydb_1[5:0] | joydb_2[5:0]),

);

////////////////////////////////////////////////////////////////////////////////
// VIDEO
////////////////////////////////////////////////////////////////////////////////

wire [7:0] r, g, b;
wire hsync, vsync;
wire hblank, vblank;
wire video_enable;
wire [2:0] fx = status[6:4];
wire [2:0] sl = fx ? fx - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_video;
assign CE_PIXEL = 1;
assign VGA_DE = video_enable;
assign VGA_HS = hsync;
assign VGA_VS = vsync;
assign VGA_R  = r;
assign VGA_G  = g;
assign VGA_B  = b;
assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];
assign VGA_SCALER = 0;

////////////////////////////////////////////////////////////////////////////////
// CONTROLS
////////////////////////////////////////////////////////////////////////////////

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];

reg key_left  = 0;
reg key_right = 0;
reg key_down  = 0;
reg key_up    = 0;
reg key_ctrl  = 0;
reg key_alt   = 0;
reg key_space = 0;
reg key_1     = 0;
reg key_2     = 0;
reg key_5     = 0;
reg key_6     = 0;
reg key_9     = 0;
reg key_0     = 0;
reg key_a     = 0;
reg key_s     = 0;
reg key_q     = 0;
reg key_r     = 0;
reg key_f     = 0;
reg key_d     = 0;
reg key_g     = 0;
reg key_p     = 0;

always @(posedge clk_sys) begin
  reg old_state;
  old_state <= ps2_key[10];

  if (old_state != ps2_key[10]) begin
    case (code)
      'h75: key_up    <= pressed;
      'h72: key_down  <= pressed;
      'h6B: key_left  <= pressed;
      'h74: key_right <= pressed;
      'h14: key_ctrl  <= pressed;
      'h11: key_alt   <= pressed;
      'h29: key_space <= pressed;
      'h16: key_1     <= pressed;
      'h1E: key_2     <= pressed;
      'h2E: key_5     <= pressed;
      'h36: key_6     <= pressed;
      'h46: key_9     <= pressed;
      'h45: key_0     <= pressed;
      'h1C: key_a     <= pressed;
      'h1B: key_s     <= pressed;
      'h15: key_q     <= pressed;
      'h2D: key_r     <= pressed;
      'h2B: key_f     <= pressed;
      'h23: key_d     <= pressed;
      'h34: key_g     <= pressed;
      'h4d: key_p     <= pressed;
    endcase
  end
end

wire player_1_up       = key_up    | joystick_0[3];
wire player_1_down     = key_down  | joystick_0[2];
wire player_1_left     = key_left  | joystick_0[1];
wire player_1_right    = key_right | joystick_0[0];
wire player_1_button_1 = key_ctrl  | joystick_0[4];
wire player_1_button_2 = key_alt   | joystick_0[5];
wire player_1_button_3 = key_space | joystick_0[6];
wire player_1_start    = key_1     | joystick_0[7];
wire player_1_coin     = key_5     | joystick_0[8];
wire player_1_pause    = key_p     | joystick_0[9];
wire player_2_up       = key_r     | joystick_1[3];
wire player_2_down     = key_f     | joystick_1[2];
wire player_2_left     = key_d     | joystick_1[1];
wire player_2_right    = key_g     | joystick_1[0];
wire player_2_button_1 = key_a     | joystick_1[4];
wire player_2_button_2 = key_s     | joystick_1[5];
wire player_2_button_3 = key_q     | joystick_1[6];
wire player_2_start    = key_2     | joystick_1[7];
wire player_2_coin     = key_6     | joystick_1[8];
wire player_2_pause    =             joystick_1[9];
wire service_1         = key_9;
wire service_2         = key_0;

////////////////////////////////////////////////////////////////////////////////
// CAVE
////////////////////////////////////////////////////////////////////////////////

wire [31:0] ddr_addr;
wire        sdram_oe;
wire [15:0] sdram_din;
wire [15:0] sdram_dout;

assign DDRAM_ADDR = ddr_addr[31:3];
assign SDRAM_DQ = sdram_oe ? sdram_din : 16'bZ;
assign sdram_dout = SDRAM_DQ;

Main main (
  // Fast clock domain
  .clock(clk_sys),
  .reset(reset_sys_1),
  // Video clock domain
  .io_videoClock(clk_video),
  .io_videoReset(reset_video_1),
  // CPU clock domain
  .io_cpuClock(clk_cpu),
  .io_cpuReset(reset_cpu_1),
  // Options
  .io_options_sdram(sdram_available & ~status[8]),
  .io_options_offset_x(status[27:24]),
  .io_options_offset_y(status[31:28]),
  .io_options_rotate(status[2]),
  .io_options_flip(status[3]),
  .io_options_compatibility(status[7]),
  .io_options_layer_sprites(status[10]),
  .io_options_layer_layer0(status[11]),
  .io_options_layer_layer1(status[12]),
  .io_options_layer_layer2(status[13]),
  // Joystick signals
  .io_joystick_player1_up(player_1_up),
  .io_joystick_player1_down(player_1_down),
  .io_joystick_player1_left(player_1_left),
  .io_joystick_player1_right(player_1_right),
  .io_joystick_player1_buttons({player_1_button_3, player_1_button_2, player_1_button_1}),
  .io_joystick_player1_start(player_1_start),
  .io_joystick_player1_coin(player_1_coin),
  .io_joystick_player1_pause(player_1_pause),
  .io_joystick_player2_up(player_2_up),
  .io_joystick_player2_down(player_2_down),
  .io_joystick_player2_left(player_2_left),
  .io_joystick_player2_right(player_2_right),
  .io_joystick_player2_buttons({player_2_button_3, player_2_button_2, player_2_button_1}),
  .io_joystick_player2_start(player_2_start),
  .io_joystick_player2_coin(player_2_coin),
  .io_joystick_player2_pause(player_2_pause),
  .io_joystick_service1(service_1),
  .io_joystick_service2(service_2),
  // Video signals
  .io_video_hSync(hsync),
  .io_video_vSync(vsync),
  .io_video_hBlank(hblank),
  .io_video_vBlank(vblank),
  .io_video_enable(video_enable),
  // Frame buffer signals
  .io_frameBuffer_enable(FB_EN),
  .io_frameBuffer_hSize(FB_WIDTH),
  .io_frameBuffer_vSize(FB_HEIGHT),
  .io_frameBuffer_format(FB_FORMAT),
  .io_frameBuffer_base(FB_BASE),
  .io_frameBuffer_stride(FB_STRIDE),
  .io_frameBuffer_vBlank(FB_VBL),
  .io_frameBuffer_lowLat(FB_LL),
  .io_frameBuffer_forceBlank(FB_FORCE_BLANK),
  // DDR
  .io_ddr_rd(DDRAM_RD),
  .io_ddr_wr(DDRAM_WE),
  .io_ddr_addr(ddr_addr),
  .io_ddr_mask(DDRAM_BE),
  .io_ddr_din(DDRAM_DIN),
  .io_ddr_dout(DDRAM_DOUT),
  .io_ddr_waitReq(DDRAM_BUSY),
  .io_ddr_valid(DDRAM_DOUT_READY),
  .io_ddr_burstLength(DDRAM_BURSTCNT),
  // SDRAM
  .io_sdram_cke(SDRAM_CKE),
  .io_sdram_cs_n(SDRAM_nCS),
  .io_sdram_ras_n(SDRAM_nRAS),
  .io_sdram_cas_n(SDRAM_nCAS),
  .io_sdram_we_n(SDRAM_nWE),
  .io_sdram_oe(sdram_oe),
  .io_sdram_bank(SDRAM_BA),
  .io_sdram_addr(SDRAM_A),
  .io_sdram_din(sdram_din),
  .io_sdram_dout(sdram_dout),
  // Download
  .io_download_cs(ioctl_download),
  .io_download_wr(ioctl_wr),
  .io_download_waitReq(ioctl_wait),
  .io_download_index(ioctl_index),
  .io_download_addr(ioctl_addr),
  .io_download_dout(ioctl_dout),
  // RGB output
  .io_rgb_r(r),
  .io_rgb_g(g),
  .io_rgb_b(b),
  // Audio output
  .io_audio_left(AUDIO_L),
  .io_audio_right(AUDIO_R),
  // LEDs
  .io_led_power(LED_POWER[0]),
  .io_led_disk(LED_DISK[0]),
  .io_led_user(LED_USER)
);

endmodule
