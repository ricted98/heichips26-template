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

module kbd_decoder (reset, clk, valid, scancode, note, high_frequency_pwm_counter, high_frequency_pwm_enable);

     input reset, clk, valid;
     input [7:0] scancode;

     output reg [2:0] note;
     output reg [10:0] high_frequency_pwm_counter;
     output reg high_frequency_pwm_enable;


     // Simple decoder based on the (valid) button pressed by the keyboard
     always @(posedge reset or posedge clk) begin
          if (reset) begin
               high_frequency_pwm_counter <= 0;
               high_frequency_pwm_enable <= 0;
               note <= 0;
          end
          else if (valid) begin
               case (scancode)
                    8'h76: begin                               // Character: Esc (no note played or displayed)
                         high_frequency_pwm_counter <= 0;
                         high_frequency_pwm_enable <= 0;
                         note <= 0;
                    end
                    8'h23: begin                               // Character: D (Do)
                         high_frequency_pwm_counter <= 1908;
                         high_frequency_pwm_enable <= 1;
                         note <= 1;
                    end
                    8'h2D: begin                               // Character: R (Re)
                         high_frequency_pwm_counter <= 1700;
                         high_frequency_pwm_enable <= 1;
                         note <= 2;
                    end
                    8'h3A: begin                               // Character: M (Mi)
                         high_frequency_pwm_counter <= 1515;
                         high_frequency_pwm_enable <= 1;
                         note <= 3;
                    end
                    8'h2B: begin                               // Character: F (Fa)
                         high_frequency_pwm_counter <= 1432;
                         high_frequency_pwm_enable <= 1;
                         note <= 4;
                    end
                    8'h1B: begin                               // Character: S (Sol)
                         high_frequency_pwm_counter <= 1275;
                         high_frequency_pwm_enable <= 1;
                         note <= 5;
                    end
                    8'h4B: begin                               // Character: L (La)
                         high_frequency_pwm_counter <= 1136;
                         high_frequency_pwm_enable <= 1;
                         note <= 6;
                    end
                    8'h21: begin                               // Character: C (Ci)
                         high_frequency_pwm_counter <= 1012;
                         high_frequency_pwm_enable <= 1;
                         note <= 7;
                    end
                    default: begin                             // Holds display as is, cuts the sound
                         high_frequency_pwm_counter <= 0;
                         high_frequency_pwm_enable <= 0;
                    end
               endcase
          end
     end


endmodule
