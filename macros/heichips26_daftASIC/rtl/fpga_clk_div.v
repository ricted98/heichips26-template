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

module fpga_clk_div (reset, clk, pixel_clk);

     input reset, clk;
     output pixel_clk;

     wire clk_25mhz_unbuffered;

     PLLE2_ADV #(
          .BANDWIDTH("OPTIMIZED"),
          .COMPENSATION("ZHOLD"),
          .STARTUP_WAIT("FALSE"),
          .REF_JITTER1(0.010),
          .CLKIN1_PERIOD(10.0),       // 100 MHz input clock
          .CLKFBOUT_MULT(1),          // Multiply by 1 -> 100 MHz VCO
          .CLKOUT0_DIVIDE(4),         // Divide by 4 -> 25 MHz output clock
          .DUTY_CYCLE0(0.5)
     ) pll_inst (
         .CLKIN1(clk),
         .CLKOUT0(clk_25mhz_unbuffered),
         .CLKFBIN(clkfb),
         .CLKFBOUT(clkfb),
         .PWRDWN(1'b0),
         .RST(reset)
     );

     BUFG bufg_inst (
         .I(clk_25mhz_unbuffered),
         .O(pixel_clk)
     );


endmodule
