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

module fpga_top_module (reset, clk, ps2clk, ps2data, hsync, vsync, red, green, blue, pwm);

     input reset, clk, ps2clk, ps2data;
     output hsync, vsync, pwm;
     output [3:0] red, green, blue;

     wire pixel_clk, red_single, green_single, blue_single;

     clk_div for_pixel_clk (reset, clk, pixel_clk);
     top_module daftASIC (reset, pixel_clk, ps2clk, ps2data, hsync, vsync, red_single, green_single, blue_single, pwm);

     assign red = {4{red_single}};
     assign green = {4{green_single}};
     assign blue = {4{blue_single}};

endmodule
