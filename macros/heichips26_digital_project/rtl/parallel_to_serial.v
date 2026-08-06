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

module parallel_to_serial (reset, clk, data, note_display_area, note_serial_out);
     input [34:0] data;
     input reset, clk, note_display_area;
     output reg note_serial_out;

     reg [5:0] counter;


     // Shift register to bit-shift out the current line of the character ROM
     // when we are within the display area, otherwise do nothing
     always @(posedge clk or posedge reset) begin
          if (reset) begin
               counter <= 0;
               note_serial_out <= 0;
          end
          else begin
               if (note_display_area == 0) begin
                    counter <= 0;
                    note_serial_out <= 0;
               end
               else begin
                    note_serial_out <= data[34 - counter];
                    if (counter == 34) counter <= 0;
                    else counter <= counter + 1;
               end
          end
     end

endmodule
