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

module quarter_line_stem_down_rom (address, data);

     input [5:0] address;
     output reg [31:0] data;


     always @(address) begin
          case (address)
                0: data = 32'b00000000000000011110000000000000;
                1: data = 32'b00000000000001111111100000000000;
                2: data = 32'b00000000000011111111110000000000;
                3: data = 32'b00000000000111111111111000000000;
                4: data = 32'b00000000001111111111111100000000;
                5: data = 32'b00000000001111111111111100000000;
                6: data = 32'b00000000011111111111111110000000;
                7: data = 32'b11111111111111111111111111111111;
                8: data = 32'b11111111111111111111111111111111;
                9: data = 32'b11111111111111111111111111111111;
               10: data = 32'b00000000011111111111111110000000;
               11: data = 32'b00000000011111111111111100000000;
               12: data = 32'b00000000011111111111111100000000;
               13: data = 32'b00000000011111111111111000000000;
               14: data = 32'b00000000011111111111110000000000;
               15: data = 32'b00000000011101111111100000000000;
               16: data = 32'b00000000011100011110000000000000;
               17: data = 32'b00000000011100000000000000000000;
               18: data = 32'b00000000011100000000000000000000;
               19: data = 32'b00000000011100000000000000000000;
               20: data = 32'b00000000011100000000000000000000;
               21: data = 32'b00000000011100000000000000000000;
               22: data = 32'b00000000011100000000000000000000;
               23: data = 32'b00000000011100000000000000000000;
               24: data = 32'b00000000011100000000000000000000;
               25: data = 32'b00000000011100000000000000000000;
               26: data = 32'b00000000011100000000000000000000;
               27: data = 32'b00000000011100000000000000000000;
               28: data = 32'b00000000011100000000000000000000;
               29: data = 32'b00000000011100000000000000000000;
               30: data = 32'b00000000011100000000000000000000;
               31: data = 32'b00000000011100000000000000000000;
               32: data = 32'b00000000011100000000000000000000;
               33: data = 32'b00000000011100000000000000000000;
               34: data = 32'b00000000011100000000000000000000;
               35: data = 32'b00000000011100000000000000000000;
               36: data = 32'b00000000011100000000000000000000;
               37: data = 32'b00000000011100000000000000000000;
               38: data = 32'b00000000011100000000000000000000;
               39: data = 32'b00000000011100000000000000000000;
               40: data = 32'b00000000011100000000000000000000;
               41: data = 32'b00000000011100000000000000000000;
               42: data = 32'b00000000011100000000000000000000;
               43: data = 32'b00000000011100000000000000000000;
               44: data = 32'b00000000011100000000000000000000;
               45: data = 32'b00000000011100000000000000000000;
               46: data = 32'b00000000011100000000000000000000;
               default: data = 32'b0;
          endcase
     end


endmodule
