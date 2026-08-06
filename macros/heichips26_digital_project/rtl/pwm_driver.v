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

module pwm_driver (reset, clk, enable, high_frequency_pwm_counter, high_frequency_pwm_enable, pwm);

     input reset, clk, enable, high_frequency_pwm_enable;
     input [10:0] high_frequency_pwm_counter;
     output reg pwm;

     reg [10:0] period_counter;


     // Create output pulse
     always @(posedge reset or posedge clk) begin
          if (reset) begin
               pwm <= 0;
               period_counter <= 0;
          end
          else if (enable) begin
               if (high_frequency_pwm_enable) begin
                    if (period_counter == high_frequency_pwm_counter) begin
                         period_counter <= 0;
                         pwm <= ~pwm;
                    end
                    else period_counter <= period_counter + 1;
               end
          end
     end

endmodule
