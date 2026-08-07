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

module full_note_memory (address, data);

     input [7:0] address;
     output reg [31:0] data;

     wire [31:0] data_space_stem_up, data_line_stem_up, data_space_stem_down, data_line_stem_down;
     wire [1:0] selector;


     assign selector = address[7:6];

     full_space_stem_up_rom __space_stem_up_rom (address[5:0], data_space_stem_up);
     full_line_stem_up_rom __line_stem_up_rom (address[5:0], data_line_stem_up);
     full_space_stem_down_rom __space_stem_down_rom (address[5:0], data_space_stem_down);
     full_line_stem_down_rom __line_stem_down_rom (address[5:0], data_line_stem_down);

     always @(selector or data_space_stem_up or data_line_stem_up or data_space_stem_down or data_line_stem_down) begin
          case (selector)
               2'b00: data = data_space_stem_up;
               2'b01: data = data_line_stem_up;
               2'b10: data = data_space_stem_down;
               2'b11: data = data_line_stem_down;
          endcase
     end


endmodule
