// SPDX-FileCopyrightText: © 2026 The HeiChips Contributors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module basys3_top (
    input logic clk,  // 100 MHz

    input  logic [15:0] sw,
    output logic [15:0] led,
    input  logic        btnC,
    input  logic        btnU,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnD,

    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaBlue,
    output logic [3:0]  vgaGreen,

    output logic        Hsync,
    output logic        Vsync,

    input  logic        PS2Clk,
    input  logic        PS2Data,
    input  logic        pwm

    // Pmod JA
    input logic [7:0] JA
);

    logic rst_n;
    logic ena;
    logic [7:0] ui_in;
    logic [7:0] uio_in;
    logic [7:0] uo_out;
    logic [7:0] uio_out;
    logic [7:0] uio_oe;
    logic       clk_25MHz;

    heichips26_daftASIC daftASIC_i (
        .ui_in,           // Dedicated inputs
        .uo_out,          // Dedicated outputs
        .uio_in,          // IOs: Input path
        .uio_out,         // IOs: Output path
        .uio_oe,          // IOs: Enable path (active high: 0=input, 1=output)
        .ena,             // enable - goes high when design is selected
        .clk (clk_25MHz), // clock
        .rst_n            // not reset
    );

    // Assignments

    assign ui_in  [0] = PS2Data;
    assign ui_in  [1] = PS2Clk;
    assign ui_in[7:2] = '0;

    assign uio_in = '0;

    assign led[7:0] = uo_out;
    assign led[15:8] = uio_out;

    assign ena = 1'b1;
    assign rst_n = !btnC;

    assign Hsync    = uo_out[0];
    assign Vsync    = uo_out[1];
    assign vgaRed   = {4{uo_out[2]}};
    assign vgaGreen = {4{uo_out[3]}};
    assign vgaBlue  = {4{uo_out[4]}};

    assign JA[0]    = uo_out[5];

    // Clock divider 100 MHz -> 25 MHz

    fpga_clk_div clk_div_25MHz (
        .reset   (rst_n),
        .clk,
        .clk_out (clk_25MHz)
    );

endmodule
