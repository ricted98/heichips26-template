// Copyright 2026 Alexander-Odysseus Farmakis
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License"); you may
// not use this file except in compliance with the License, or, at your option,
// the Apache License version 2.0. You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.

module top_module (reset, pixel_clk, ps2clk, ps2data, hsync, vsync, red, green, blue, pwm);

     localparam ROM_DATA_WIDTH = 32;
     localparam ROM_ADDR_WIDTH = 10;
     localparam PWM_COUNTER_WIDTH = 16;

     input reset, pixel_clk, ps2clk, ps2data;
     output hsync, vsync, pwm;
     output red, green, blue;

     reg [2:0] rgb_out;

     wire [ROM_DATA_WIDTH-1:0] data;
     wire [ROM_ADDR_WIDTH-1:0] address;
	wire [PWM_COUNTER_WIDTH-1:0] high_frequency_pwm_counter;
     wire [7:0] scancode;
     wire [2:0] note;
     wire valid, pwm_clk, line_placement, clef_placement, note_display_area;
     wire high_frequency_pwm_enable;
     wire note_serial_out;
     wire vibrato, staccato;

     cnt25 pwm_drive_clock (reset, pixel_clk, 1'b1, pwm_clk);

     // Keyboard-related instantiations
     kbd_protocol_modified keyboard_protocol (reset, pixel_clk, ps2clk, ps2data, scancode, valid);
     kbd_decoder scan_decode (
          reset,
          pixel_clk,
          valid,
          scancode,
          note,
          high_frequency_pwm_counter,
          high_frequency_pwm_enable,
          vibrato,
          staccato
     );

     // Display-related instantiations
     vga_protocol #(
          .ROM_DATA_WIDTH (ROM_DATA_WIDTH),
          .ROM_ADDR_WIDTH (ROM_ADDR_WIDTH)
     ) monitor (
          .reset             (reset),
          .clk               (pixel_clk),
          .note              (note),
          .hsync             (hsync),
          .vsync             (vsync),
          .clef_placement    (clef_placement),
          .line_placement    (line_placement),
          .note_display_area (note_display_area),
          .memory_address    (address)
     );

	note_memory memory (address, data);

     parallel_to_serial #(
          .ROM_DATA_WIDTH (ROM_DATA_WIDTH)
     ) p2s (
          reset,
          pixel_clk,
          data,
          note_display_area,
          note_serial_out
     );

     // Audio-related instantiations
     pwm_driver piezo_driver_module (
          .reset                                                   (reset),
          .clk                                                 (pixel_clk),
          .enable                                                (pwm_clk),
          .valid                                                   (valid),
          .scancode                                             (scancode),
          .note_loaded                                              (note),
          .high_frequency_pwm_counter_init    (high_frequency_pwm_counter),
          .high_frequency_pwm_enable           (high_frequency_pwm_enable),
          .vibrato                                               (vibrato),
          .staccato                                             (staccato),
          .pwm                                                       (pwm)
     );

     // Replication operator to produce the RGB for display easily.
     // No need to carry 9 bits around before we reach the display
     // assign {red, green, blue} = {3{line_placement | note_serial_out | clef_placement}};
     always @(rgb_out or vibrato or staccato or line_placement or note_serial_out or note_display_area or clef_placement) begin
          if (note_display_area) begin
               if (vibrato & staccato) rgb_out = 3'b110 & {3{note_serial_out}};
               else if (vibrato) rgb_out = 3'b101 & {3{note_serial_out}};
               else if (staccato) rgb_out = 3'b011 & {3{note_serial_out}};
               else rgb_out = {3{note_serial_out}};
          end
          else if (clef_placement | line_placement) rgb_out = 3'b111;
          else rgb_out = 3'b000;
     end

     assign {red, green, blue} = rgb_out;


endmodule
