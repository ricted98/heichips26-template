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

module vga_protocol (reset, clk, note, hsync, vsync, line_placement, display_area, memory_address);

     // VGA parameters (Horizontal)
     parameter H_FRONT_PORCH = 16;
     parameter H_SYNC_PULSE = 96;
     parameter H_BACK_PORCH = 48;
     parameter H_VISIBLE_PIXELS = 640;
     localparam H_END = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + H_VISIBLE_PIXELS;      // H_END = 800

     // VGA parameters (Vertical)
     parameter V_FRONT_PORCH = 12;
     parameter V_SYNC_PULSE = 2;
     parameter V_BACK_PORCH = 35;
     parameter V_VISIBLE_LINES = 400;
     localparam V_END = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE_LINES;      // V_END = 449

     // Sheet line parameters
     parameter LINE_THICKNESS = 3;
     parameter LINE_TO_LINE_DISTANCE = 20;
     parameter BEGINNING_FROM_TOP = 90;
     localparam LINE_FIRST = BEGINNING_FROM_TOP + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 90 + (12 + 2 + 35) = 139
     localparam LINE_SECOND = LINE_FIRST + LINE_TO_LINE_DISTANCE;
     localparam LINE_THIRD = LINE_SECOND + LINE_TO_LINE_DISTANCE;
     localparam LINE_FOURTH = LINE_THIRD + LINE_TO_LINE_DISTANCE;
     localparam LINE_FIFTH = LINE_FOURTH + LINE_TO_LINE_DISTANCE;
     localparam LINE_SIXTH = LINE_FIFTH + LINE_TO_LINE_DISTANCE;

     // Note parameters
     localparam NOTE_THICKNESS = 35;
     localparam H_LEFT_BORDER = (H_SYNC_PULSE + H_BACK_PORCH + H_END - NOTE_THICKNESS - 1) / 2;
     localparam H_RIGHT_BORDER = H_LEFT_BORDER + NOTE_THICKNESS;

     input reset, clk;
     input [2:0] note;
     output hsync, vsync, line_placement, display_area;
     output [7:0] memory_address;

     reg [9:0] pixel_counter;
     reg [8:0] line_counter;
     reg [7:0] top_of_note;

     wire [1:0] note_type;
	wire [8:0] bottom_of_note;
     wire [5:0] line_from_memory;


     always @(posedge reset or posedge clk) begin
          if (reset) begin
               pixel_counter <= 0;
               line_counter <= 0;
          end
          else if (pixel_counter == H_END) begin                    // If we're on the right-hand side of the monitor
               pixel_counter <= 0;
               if (line_counter == V_END) line_counter <= 0;        // If we're on the final line, zero the line_counter to start over
               else line_counter <= line_counter + 1;               // Otherwise, continue incrementing it
          end
          else pixel_counter <= pixel_counter + 1;                  // If we're NOT on the right-hand side
     end

     // Synchronization signals
     // If we want a 25MHz clock, we can get 640 x 400 resolution @ 70 FPS, with the following parameters:
     // 112 > pixel_counter > 15     and     14 > line_counter > 11
     assign hsync = ((pixel_counter > (H_FRONT_PORCH - 1)) && (pixel_counter < (H_FRONT_PORCH + H_SYNC_PULSE))) ? 1'b0 : 1'b1;
     assign vsync = ((line_counter > (V_FRONT_PORCH - 1)) && (line_counter < (V_FRONT_PORCH + V_SYNC_PULSE))) ? 1'b1 : 1'b0;

     // Create 5 lines (3-pixel thick each) for the sheet lines that will ALWAYS display
     // I need logical operators here instead of gates basically, which is why we use "||" instead of "|"
     assign line_placement = ((line_counter > LINE_FIRST)  && (line_counter < LINE_FIRST+LINE_THICKNESS+1)  &&
                              (pixel_counter > H_END-H_VISIBLE_PIXELS-1) && (pixel_counter < H_END))            ||
                             ((line_counter > LINE_SECOND) && (line_counter < LINE_SECOND+LINE_THICKNESS+1) &&
                              (pixel_counter > H_END-H_VISIBLE_PIXELS-1) && (pixel_counter < H_END))            ||
                             ((line_counter > LINE_THIRD)  && (line_counter < LINE_THIRD+LINE_THICKNESS+1)  &&
                              (pixel_counter > H_END-H_VISIBLE_PIXELS-1) && (pixel_counter < H_END))            ||
                             ((line_counter > LINE_FOURTH) && (line_counter < LINE_FOURTH+LINE_THICKNESS+1) &&
                              (pixel_counter > H_END-H_VISIBLE_PIXELS-1) && (pixel_counter < H_END))            ||
                             ((line_counter > LINE_FIFTH)  && (line_counter < LINE_FIFTH+LINE_THICKNESS+1)  &&
                              (pixel_counter > H_END-H_VISIBLE_PIXELS-1) && (pixel_counter < H_END));

     // Optimized logic for the memory pointer
     assign note_type = {~|note | &note, ~note[0]};

     // Logic for top and bottom borders of note being displayed.
     // Basically, there are 3 types of notes: "through line", "between lines" and "upside-down"
     // "Through line"    -> Do, Mi, Sol
     // "Between lines"   -> Re, Fa, La
     // "Upside down"     -> Ci
     assign bottom_of_note = top_of_note + 63;
     always @(posedge reset or posedge clk) begin
          if (reset) top_of_note <= 0;
          else begin
               case(note)
                    3'b000: top_of_note <= 0;
                    3'b001: top_of_note <= LINE_FOURTH + LINE_THICKNESS + 1;
                    3'b010: top_of_note <= LINE_FIFTH - 2*LINE_TO_LINE_DISTANCE + 5*LINE_THICKNESS - 1;
                    3'b011: top_of_note <= LINE_THIRD + LINE_THICKNESS + 1;
                    3'b100: top_of_note <= LINE_FOURTH - 2*LINE_TO_LINE_DISTANCE + 5*LINE_THICKNESS - 1;
                    3'b101: top_of_note <= LINE_SECOND + LINE_THICKNESS + 1;
                    3'b110: top_of_note <= LINE_THIRD - 2*LINE_TO_LINE_DISTANCE + 5*LINE_THICKNESS - 1;
                    3'b111: top_of_note <= LINE_THIRD - 2*LINE_THICKNESS;
               endcase
          end
     end


     // Movable display area so as to use 3 types of notes basically instead of just a bigger ROM and 7 hard-coded notes
     assign display_area = ((pixel_counter >= H_LEFT_BORDER) && (pixel_counter <= H_RIGHT_BORDER) &&
                               (line_counter >= top_of_note) && (line_counter <= bottom_of_note));
     assign line_from_memory = (line_counter >= top_of_note) ? (line_counter - top_of_note) : 0;

     // Final address to go to Note Character ROM
	assign memory_address = {note_type, line_from_memory};


endmodule
