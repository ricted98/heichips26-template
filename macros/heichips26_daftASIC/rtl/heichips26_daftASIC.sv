// SPDX-FileCopyrightText: © 2026 XXX Authors
// SPDX-License-Identifier: Apache-2.0

// Adapted from the Tiny Tapeout template

`default_nettype none

module heichips26_daftASIC (
`ifdef USE_POWER_PINS
    inout  wire VPWR,
    inout  wire VGND,
`endif
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals
    logic red, green, blue;
    logic hsync, vsync;
    // PWM signals
    logic pwm;
    // PS2 signals
    logic ps2clk, ps2data;

    // Inputs
    assign ps2clk  = ui_in[1];
    assign ps2data = ui_in[0];
    // Outputs
    assign uo_out   [0] = hsync;
    assign uo_out   [1] = vsync;
    assign uo_out   [2] = red;
    assign uo_out   [3] = green;
    assign uo_out   [4] = blue;
    assign uo_out   [5] = pwm;
    assign uo_out [7:6] = '0;
    // Bidir (force to outputs)
    assign uio_oe       = '1;
    assign uio_out[7:0] = '0;

    // List all unused inputs to prevent warnings
    wire _unused;
    assign _unused = &{ena, ui_in[7:2], uio_in};

    top_module music_synth_i (
        .pixel_clk (clk),
        .reset     (~rst_n),
        .ps2clk    (ps2clk),
        .ps2data   (ps2data),
        .hsync     (hsync),
        .vsync     (vsync),
        .red       (red),
        .green     (green),
        .blue      (blue),
        .pwm       (pwm)
    );

endmodule
