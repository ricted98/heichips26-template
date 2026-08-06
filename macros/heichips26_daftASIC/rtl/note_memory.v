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

module note_memory (address, data);

     input [9:0] address;
     output reg [31:0] data;

     wire [31:0] data_full, data_half, data_quarter, data_eighth;
     wire [1:0] selector;


     assign selector = address[9:8];

     full_note_memory full_rom (address[7:0], data_full);
     half_note_memory half_rom (address[7:0], data_half);
     quarter_note_memory quarter_rom (address[7:0], data_quarter);
     eighth_note_memory eighth_rom (address[7:0], data_eighth);

     // Address field: {note duration} , {line / ~space} , {stem ~up / down} , { character }
     //                {    2-bit    } , {    1-bit    } , {     1-bit     } , {   6-bit   }
     //                {    9 | 8    } , {      7      } , {       6       } , { 5 | … | 0 }
     always @(selector or data_full or data_half or data_quarter or data_eighth) begin
          case (selector)
               2'b00: data = data_full;
               2'b01: data = data_half;
               2'b10: data = data_quarter;
               2'b11: data = data_eighth;
          endcase
     end


endmodule
