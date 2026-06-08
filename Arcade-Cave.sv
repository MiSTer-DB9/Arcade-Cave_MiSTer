/*
 *   __   __     __  __     __         __
 *  /\ "-.\ \   /\ \/\ \   /\ \       /\ \
 *  \ \ \-.  \  \ \ \_\ \  \ \ \____  \ \ \____
 *   \ \_\\"\_\  \ \_____\  \ \_____\  \ \_____\
 *    \/_/ \/_/   \/_____/   \/_____/   \/_____/
 *   ______     ______       __     ______     ______     ______
 *  /\  __ \   /\  == \     /\ \   /\  ___\   /\  ___\   /\__  _\
 *  \ \ \/\ \  \ \  __<    _\_\ \  \ \  __\   \ \ \____  \/_/\ \/
 *   \ \_____\  \ \_____\ /\_____\  \ \_____\  \ \_____\    \ \_\
 *    \/_____/   \/_____/ \/_____/   \/_____/   \/_____/     \/_/
 *
 * https://joshbassett.info
 * https://twitter.com/nullobject
 * https://github.com/nullobject
 *
 * Copyright (c) 2022 Josh Bassett
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

module emu
(
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
  //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
  output [12:0] VIDEO_ARX,
  output [12:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler
  output        VGA_DISABLE, // analog out is off

  input  [11:0] HDMI_WIDTH,
  input  [11:0] HDMI_HEIGHT,
  output        HDMI_FREEZE,
  output        HDMI_BLACKOUT,
  output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
  // Use framebuffer in DDRAM
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,
`endif
`endif

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

  //ADC
  inout   [3:0] ADC_BUS,

  //SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

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

`ifdef MISTER_DUAL_SDRAM
  //Secondary SDRAM
  //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
  input         SDRAM2_EN,
  output        SDRAM2_CLK,
  output [12:0] SDRAM2_A,
  output  [1:0] SDRAM2_BA,
  inout  [15:0] SDRAM2_DQ,
  output        SDRAM2_nCS,
  output        SDRAM2_nCAS,
  output        SDRAM2_nRAS,
  output        SDRAM2_nWE,
`endif

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
  output        USER_OSD,
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_IO[7] + per-pin push-pull mask
  output  [7:0] USER_PP,
  input   [7:0] USER_IN,
  output  [7:0] USER_OUT,
  // [MiSTer-DB9 END]

  input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign AUDIO_R   = AUDIO_L;
assign AUDIO_S   = 1;
assign AUDIO_MIX = 0;

assign VGA_DISABLE = 0;

assign LED_DISK[1] = 0;
assign LED_POWER[1] = 0;
assign BUTTONS = 0;

assign VIDEO_ARX = (!aspect_ratio) ? (orientation ? 12'd3 : 12'd4) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (orientation ? 12'd4 : 12'd3) : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
  "cave;;",
  "D0O12,Aspect ratio,Original,Fullscreen,[ARC1],[ARC2];",
  "D0O4,Flip screen,Off,On;",
  "D1O3,Rotate screen,Off,On;",
  "-;",
  "OOR,CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
  "OSV,CRT V adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
  "O57,Scandoubler,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
  "O8,Refresh rate,57Hz,60Hz;",
  "-;",
  "T9,Service mode;",
  "DIP;",
`ifdef CAVE_ENABLE_DEBUG_OVERLAY
  "P1,Debug;",
  "P1OA,Sprites,On,Off;",
  "P1OB,Layer 0,On,Off;",
  "P1OC,Layer 1,On,Off;",
  "P1OD,Layer 2,On,Off;",
  "P1OE,Debug Video,Off,On;",
  "P1OFH,Debug View,Pipeline,CPU Addr,Writes,Video,Palette,PostPC,RawSprite,Sound;",
  "P1-;",
`else
  "P1,Hardware;",
`endif
  "P1OIL,PCB,Dangun Feveron,DoDonPachi,DonPachi,ESP Ra.De.,Puzzle Uo Poko,Guwange,Gaia,Hotdog Storm,Mazinger Z;",
  "-;",
  // [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
  "O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
  "O[125],UserIO Players, 1 Player,2 Players;",
  // [MiSTer-DB9-Pro END]
  "R0,Reset;",
  "J,B0,B1,B2,B3,Start,Coin,Pause;",
  "V,v",`BUILD_DATE," by nullobject;"
};

////////////////////////////////////////////////////////////////////////////////
// CLOCK AND RESET
////////////////////////////////////////////////////////////////////////////////

wire pll_sys_locked, pll_video_locked;
wire clk_sys, clk_cpu, clk_video;
wire rst_sys, rst_cpu, rst_video;
reg  rst_pll;

// Resets the PLL if it loses lock
always @(posedge clk_sys or posedge RESET) begin
  reg old_locked;
  reg [7:0] rst_cnt;

  if (RESET) begin
    rst_pll <= 0;
    rst_cnt <= 8'h00;
  end else begin
    old_locked <= pll_sys_locked;
    if (old_locked && !pll_sys_locked) begin
      rst_cnt <= 8'hff; // keep reset high for 256 cycles
      rst_pll <= 1;
    end else begin
      if (rst_cnt != 8'h00)
        rst_cnt <= rst_cnt - 8'h1;
      else
        rst_pll <= 0;
    end
  end
end

pll pll (
  .refclk(CLK_50M),
  .rst(rst_pll),
  .locked(pll_sys_locked),
  .outclk_0(clk_sys),
  .outclk_1(clk_cpu)
);

pll_video pll_video (
  .refclk(CLK_50M),
  .rst(rst_pll),
  .locked(pll_video_locked),
  .outclk_0(clk_video)
);

assign DDRAM_CLK = clk_sys;
assign CLK_VIDEO = clk_video;

reset_ctrl reset_sys_ctrl (
  .clk(clk_sys),
  .rst_i(RESET | ~pll_sys_locked),
  .rst_o(rst_sys)
);

reset_ctrl reset_cpu_ctrl (
  .clk(clk_cpu),
  .rst_i(RESET | ~pll_sys_locked | status[0] | buttons[1]),
  .rst_o(rst_cpu)
);

reset_ctrl reset_video_ctrl (
  .clk(clk_video),
  .rst_i(RESET | ~pll_video_locked),
  .rst_o(rst_video)
);

altddio_out
#(
  .extend_oe_disable("OFF"),
  .intended_device_family("Cyclone V"),
  .invert_output("OFF"),
  .lpm_hint("UNUSED"),
  .lpm_type("altddio_out"),
  .oe_reg("UNREGISTERED"),
  .power_up_high("OFF"),
  .width(1)
)
sdramclk_ddr
(
  .datain_h(1'b0),
  .datain_l(1'b1),
  .outclock(clk_sys),
  .dataout(SDRAM_CLK),
  .aclr(1'b0),
  .aset(1'b0),
  .oe(1'b1),
  .outclocken(1'b1),
  .sclr(1'b0),
  .sset(1'b0)
);

////////////////////////////////////////////////////////////////////////////////
// HPS IO
////////////////////////////////////////////////////////////////////////////////

wire  [1:0] buttons;
wire [127:0] status;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
reg         new_vmode = 0;
wire        direct_video;
wire [15:0] sdram_sz;

wire        ioctl_upload;
wire        ioctl_download;
wire        ioctl_rd;
wire        ioctl_wr;
wire        ioctl_wait_n;
wire  [7:0] ioctl_index;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_din;
wire [15:0] ioctl_dout;

wire [10:0] ps2_key;
wire [31:0] joystick_0_USB, joystick_1_USB;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression (e.g. `mt32_use` under `ifndef SECOND_MT32`, `~mt32_disable` for
// TRS-80's inverted polarity). Suppresses the OSD-open autodetect probe so it
// doesn't read the RPi's I2C master traffic as a ghost Saturn signature.
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// Legacy 3-bit alias for fork-specific MT32 / SNAC fallback code. Non-canonical
// RHS variants (ext_iec_en, mt32_disable) need a hand-port — alias is raw.
wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire         pad_1_6btn, pad_2_6btn;
wire  [15:0] joy_raw_payload;

joydb joydb (
  .clk             ( CLK_JOY         ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .pad_1_6btn      ( pad_1_6btn      ),
  .pad_2_6btn      ( pad_2_6btn      ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
assign USER_PP  = USER_PP_DRIVE;
// [MiSTer-DB9 END]

// Cave joystick layout: [10]=Pause, [9]=Coin, [8]=Start, [7:4]=B3..B0, [3:0]=URLD.
// joydb layout:         [12]=L_trigger (Saturn), [11]=Mode, [10]=Start, [7:0]=ZYXCBAUDLR.
// 1P DB mode (joydb_1ena & ~joydb_2ena): USB joy_0 falls through to player 2 so a USB pad can play P2.
// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
wire [31:0] joystick_0 = joydb_1ena ? (OSD_STATUS ? 32'b0 : {joydb_1[12],joydb_1[11],joydb_1[10],joydb_1[7:0]}) : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? (OSD_STATUS ? 32'b0 : {joydb_2[12],joydb_2[11],joydb_2[10],joydb_2[7:0]}) : joydb_1ena ? joystick_0_USB : joystick_1_USB;
// [MiSTer-DB9-Pro END]

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io (
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),

  .buttons(buttons),
  .status(status),
  .status_menumask({15'd0, direct_video}),
  .forced_scandoubler(forced_scandoubler),
  .new_vmode(new_vmode),
  .gamma_bus(gamma_bus),
  .direct_video(direct_video),
  .sdram_sz(sdram_sz),

  .ioctl_upload(ioctl_upload),
  .ioctl_download(ioctl_download),
  .ioctl_rd(ioctl_rd),
  .ioctl_wr(ioctl_wr),
  .ioctl_wait(~ioctl_wait_n),
  .ioctl_index(ioctl_index),
  .ioctl_addr(ioctl_addr),
  .ioctl_din(ioctl_din),
  .ioctl_dout(ioctl_dout),

  .joystick_0(joystick_0_USB),
  .joystick_1(joystick_1_USB),

  .ps2_key(ps2_key),
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
  .joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
  // [MiSTer-DB9 END]
  // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
  .saturn_unlocked(saturn_unlocked)
  // [MiSTer-DB9-Pro END]
);

////////////////////////////////////////////////////////////////////////////////
// VIDEO
////////////////////////////////////////////////////////////////////////////////

wire ce_pix;
wire [23:0] rgb;
wire hsync, vsync;
wire hblank, vblank;
wire core_video_rotated;
wire [1:0] aspect_ratio = status[2:1];
wire orientation = core_video_rotated;
wire [2:0] fx = status[7:5];
`ifdef CAVE_ENABLE_DEBUG_OVERLAY
wire debug_video = status[14];
wire [2:0] debug_view = status[17:15];
wire option_sprite = ~status[10];
wire option_layer_0 = ~status[11];
wire option_layer_1 = ~status[12];
wire option_layer_2 = ~status[13];
`else
wire debug_video = 1'b0;
wire [2:0] debug_view = 3'd0;
wire option_sprite = 1'b1;
wire option_layer_0 = 1'b1;
wire option_layer_1 = 1'b1;
wire option_layer_2 = 1'b1;
`endif
wire [2:0] sl = fx ? fx - 1'd1 : 3'd0;
wire scandoubler = fx || forced_scandoubler;

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

video_mixer #(.LINE_LENGTH(388), .HALF_DEPTH(0), .GAMMA(1)) video_mixer (
  .CLK_VIDEO(clk_video),
  .CE_PIXEL(CE_PIXEL),
  .ce_pix(ce_pix),

  .scandoubler(scandoubler),
  .hq2x(fx==1),
  .gamma_bus(gamma_bus),

  .R(rgb[23:16]),
  .G(rgb[15:8]),
  .B(rgb[7:0]),

  .HSync(hsync),
  .VSync(vsync),
  .HBlank(hblank),
  .VBlank(vblank),

  .VGA_R(VGA_R),
  .VGA_G(VGA_G),
  .VGA_B(VGA_B),
  .VGA_VS(VGA_VS),
  .VGA_HS(VGA_HS),
  .VGA_DE(VGA_DE)
);

// Update HPS when video mode changes
reg [1:0] video_status;
always @(posedge clk_sys) begin
    if (video_status != status[8]) begin
        video_status <= status[8];
        new_vmode <= ~new_vmode;
    end
end

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
reg key_shift = 0;
reg key_space = 0;
reg key_1     = 0;
reg key_2     = 0;
reg key_5     = 0;
reg key_6     = 0;
reg key_a     = 0;
reg key_s     = 0;
reg key_q     = 0;
reg key_r     = 0;
reg key_f     = 0;
reg key_d     = 0;
reg key_g     = 0;
reg key_p     = 0;
reg key_w     = 0;

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
      'h12: key_shift <= pressed;
      'h29: key_space <= pressed;
      'h16: key_1     <= pressed;
      'h1E: key_2     <= pressed;
      'h2E: key_5     <= pressed;
      'h36: key_6     <= pressed;
      'h1C: key_a     <= pressed;
      'h1B: key_s     <= pressed;
      'h15: key_q     <= pressed;
      'h2D: key_r     <= pressed;
      'h2B: key_f     <= pressed;
      'h23: key_d     <= pressed;
      'h34: key_g     <= pressed;
      'h4d: key_p     <= pressed;
      'h1d: key_w     <= pressed;
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
wire player_1_button_4 = key_shift | joystick_0[7];
wire player_1_start    = key_1     | joystick_0[8];
wire player_1_coin     = key_5     | joystick_0[9];
wire player_1_pause    = key_p     | joystick_0[10];
wire player_2_up       = key_r     | joystick_1[3];
wire player_2_down     = key_f     | joystick_1[2];
wire player_2_left     = key_d     | joystick_1[1];
wire player_2_right    = key_g     | joystick_1[0];
wire player_2_button_1 = key_a     | joystick_1[4];
wire player_2_button_2 = key_s     | joystick_1[5];
wire player_2_button_3 = key_q     | joystick_1[6];
wire player_2_button_4 = key_w     | joystick_1[7];
wire player_2_start    = key_2     | joystick_1[8];
wire player_2_coin     = key_6     | joystick_1[9];
wire player_2_pause    =             joystick_1[10];

////////////////////////////////////////////////////////////////////////////////
// MAIN
////////////////////////////////////////////////////////////////////////////////

wire [31:0] ddr_addr;
wire        sdram_oe_n;
wire [15:0] sdram_din;
wire [15:0] sdram_dout;

assign DDRAM_ADDR = ddr_addr[31:3];
assign SDRAM_DQ = sdram_oe_n ? sdram_din : 16'bZ;
assign sdram_dout = SDRAM_DQ;
assign SDRAM_DQMH = 0;
assign SDRAM_DQML = 0;

Cave cave (
  .reset(rst_sys),
  .cpuReset(rst_cpu),
  .videoReset(rst_video),

  .clock(clk_sys),
  .cpuClock(clk_cpu),
  .videoClock(clk_video),

  // Options
  .options_offset_x(status[27:24]),
  .options_offset_y(status[31:28]),
  .options_rotate(status[3]),
  .options_compatibility(status[8]),
  .options_service(status[9]),
  .options_layer_0(option_layer_0),
  .options_layer_1(option_layer_1),
  .options_layer_2(option_layer_2),
  .options_sprite(option_sprite),
  .options_flipVideo(status[4]),
  .options_gameIndex(status[21:18]),
  .options_debugVideo(debug_video),
  .options_debugView(debug_view),
  // Joystick signals
  .player_0_up(player_1_up),
  .player_0_down(player_1_down),
  .player_0_left(player_1_left),
  .player_0_right(player_1_right),
  .player_0_buttons({player_1_button_4, player_1_button_3, player_1_button_2, player_1_button_1}),
  .player_0_start(player_1_start),
  .player_0_coin(player_1_coin),
  .player_0_pause(player_1_pause),
  .player_1_up(player_2_up),
  .player_1_down(player_2_down),
  .player_1_left(player_2_left),
  .player_1_right(player_2_right),
  .player_1_buttons({player_2_button_4, player_2_button_3, player_2_button_2, player_2_button_1}),
  .player_1_start(player_2_start),
  .player_1_coin(player_2_coin),
  .player_1_pause(player_2_pause),
  // Video signals
  .video_clockEnable(ce_pix),
  .video_changeMode(0),
  .video_rotated(core_video_rotated),
  .video_hSync(hsync),
  .video_vSync(vsync),
  .video_hBlank(hblank),
  .video_vBlank(vblank),
  // Frame buffer control signals
  .frameBufferCtrl_enable(FB_EN),
  .frameBufferCtrl_hSize(FB_WIDTH),
  .frameBufferCtrl_vSize(FB_HEIGHT),
  .frameBufferCtrl_format(FB_FORMAT),
  .frameBufferCtrl_baseAddr(FB_BASE),
  .frameBufferCtrl_stride(FB_STRIDE),
  .frameBufferCtrl_vBlank(FB_VBL),
  .frameBufferCtrl_lowLat(FB_LL),
  .frameBufferCtrl_forceBlank(FB_FORCE_BLANK),
  // DDR
  .ddr_rd(DDRAM_RD),
  .ddr_wr(DDRAM_WE),
  .ddr_addr(ddr_addr),
  .ddr_mask(DDRAM_BE),
  .ddr_din(DDRAM_DIN),
  .ddr_dout(DDRAM_DOUT),
  .ddr_wait_n(~DDRAM_BUSY),
  .ddr_valid(DDRAM_DOUT_READY),
  .ddr_burstLength(DDRAM_BURSTCNT),
  // SDRAM
  .sdram_cke(SDRAM_CKE),
  .sdram_cs_n(SDRAM_nCS),
  .sdram_ras_n(SDRAM_nRAS),
  .sdram_cas_n(SDRAM_nCAS),
  .sdram_we_n(SDRAM_nWE),
  .sdram_oe_n(sdram_oe_n),
  .sdram_bank(SDRAM_BA),
  .sdram_addr(SDRAM_A),
  .sdram_din(sdram_din),
  .sdram_dout(sdram_dout),
  // Download
  .ioctl_upload(ioctl_upload),
  .ioctl_download(ioctl_download),
  .ioctl_rd(ioctl_rd),
  .ioctl_wr(ioctl_wr),
  .ioctl_wait_n(ioctl_wait_n),
  .ioctl_index(ioctl_index),
  .ioctl_addr(ioctl_addr),
  .ioctl_din(ioctl_din),
  .ioctl_dout(ioctl_dout),
  // RGB output
  .rgb(rgb),
  // Audio output
  .audio(AUDIO_L),
  // LEDs
  .led_power(LED_POWER[0]),
  .led_disk(LED_DISK[0]),
  .led_user(LED_USER)
);

endmodule
