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

module cnt25 (reset, clk, enable, clkdiv25);

     input reset, clk, enable;
     output clkdiv25;

     reg [5:0] cnt;


     assign clkdiv25 = (cnt==5'd24);
     always @(posedge reset or posedge clk) begin
          if (reset) cnt <= 0;
          else if (enable) begin
               if (clkdiv25) cnt <= 0;
               else cnt <= cnt + 1;
          end
     end


endmodule
