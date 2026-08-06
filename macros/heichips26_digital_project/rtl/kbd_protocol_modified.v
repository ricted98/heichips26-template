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

module kbd_protocol_modified (reset, clk, ps2clk, ps2data, scancode, valid);

     input reset, clk, ps2clk, ps2data;
     output reg [7:0] scancode;
     output reg valid;

     // Synchronize ps2clk to local clock and check for falling edge
     reg [7:0] ps2clksamples;     // Stores last 8 ps2clk samples
     reg [9:0] shift;             // Stores a serial package, excluding the stop bit;
     reg [3:0] cnt;               // Used to count the ps2data samples stored so far
     reg f0;                      // Used to indicate that f0 was encountered earlier

     wire fall_edge;    // Indicates a falling_edge at ps2clk


     always @(posedge clk or posedge reset) begin
          if (reset) ps2clksamples <= 8'd0;
          else ps2clksamples <= {ps2clksamples[7:0], ps2clk};
     end

     assign fall_edge = (ps2clksamples == 8'hF0);

     // A simple FSM is implemented here. Grab a whole package, check
     // its parity validity and output it in the scancode only if the
     // previous read value of the package was F0, that is, we only
     // trace when a button is released, NOT when it is pressed
     always @(posedge reset or posedge clk) begin
          valid <= 1'b0;      // This register will go to 1 for exactly one clock cycle ever
          if (reset) begin
               cnt <= 4'd0;
               scancode <= 8'b0;
               shift <= 9'b0;
               f0 <= 1'b0;
               valid <= 1'b0;
          end
          else if (fall_edge) begin
               if (cnt == 4'd10) begin       // We just received what should be the stop bit
                    cnt <= 4'd0;
                    // A well received serial packet
                    if ((shift[0] == 1'b0) && (ps2data == 1'b1) && (^shift[9:1] == 1'b1)) begin
                         // Following a scancode of f0. So a key is released!
                         if (f0) begin
                              scancode <= shift[8:1];
                              f0 <= 1'b0;
                              valid <= 1'b1;
                         end
                         else if (shift[8:1] == 8'hF0) f0 <= 1'b1;
                    end                      // All other packets have to do with key presses and are ignored
               end
               else begin
                    // Shift right since LSB first is transmitted
                    shift <= {ps2data, shift[9:1]};
                    cnt <= cnt + 1;
               end
          end
     end


endmodule
