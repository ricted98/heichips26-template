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

     input reset, pixel_clk, ps2clk, ps2data;
     output hsync, vsync, pwm;
     output red, green, blue;

     wire [34:0] data;
	wire [10:0] high_frequency_pwm_counter;
     wire [7:0] scancode, address;
     wire [2:0] note;
     wire valid, pwm_clk, line_placement, display_area;
     wire high_frequency_pwm_enable;
     wire note_serial_out;

     cnt25 pwm_drive_clock (reset, pixel_clk, 1'b1, pwm_clk);

     // Keyboard-related instantiations
     kbd_protocol_modified keyboard_protocol (reset, pixel_clk, ps2clk, ps2data, scancode, valid);
     kbd_decoder scan_decode (reset, pixel_clk, valid, scancode, note, high_frequency_pwm_counter, high_frequency_pwm_enable);

     // Display-related instantiations
     vga_protocol monitor (reset, pixel_clk, note, hsync, vsync, line_placement, display_area, address);
	note_memory memory (address, data);
     parallel_to_serial p2s (reset, pixel_clk, data, display_area, note_serial_out);

     // Audio-related instantiations
     pwm_driver piezo_driver_module (reset, pixel_clk, pwm_clk, high_frequency_pwm_counter, high_frequency_pwm_enable, pwm);

     // Replication operator to produce the RGB for display easily.
     // No need to carry 9 bits around before we reach the display
     assign {red, green, blue} = {3{line_placement | note_serial_out}};


endmodule
