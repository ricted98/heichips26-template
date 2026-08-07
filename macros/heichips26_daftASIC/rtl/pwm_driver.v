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

module pwm_driver (reset, clk, enable, valid, scancode, note_loaded, high_frequency_pwm_counter_init,
                   high_frequency_pwm_enable, vibrato, staccato, pwm);

     parameter PWM_COUNTER_WIDTH = 16;

     // Frequencies for notes
     parameter C4 = 1908;
     parameter D4 = 1700;
     parameter E4 = 1515;
     parameter F4 = 1432;
     parameter G4 = 1275;
     parameter A4 = 1136;
     parameter B4 = 1012;

     localparam C4_VIB_STEP = 43;
     localparam C4_VIB_UP = C4 - 8*C4_VIB_STEP;
     localparam C4_VIB_DOWN = C4 + 8*C4_VIB_STEP;

     localparam D4_VIB_STEP = 36;
     localparam D4_VIB_UP = D4 - 8*D4_VIB_STEP;
     localparam D4_VIB_DOWN = D4 + 8*D4_VIB_STEP;

     localparam E4_VIB_STEP = 29;
     localparam E4_VIB_UP = E4 - 8*E4_VIB_STEP;
     localparam E4_VIB_DOWN = E4 + 8*E4_VIB_STEP;

     localparam F4_VIB_STEP = 23;
     localparam F4_VIB_UP = F4 - 8*F4_VIB_STEP;
     localparam F4_VIB_DOWN = F4 + 8*F4_VIB_STEP;

     localparam G4_VIB_STEP = 18;
     localparam G4_VIB_UP = G4 - 8*G4_VIB_STEP;
     localparam G4_VIB_DOWN = G4 + 8*G4_VIB_STEP;

     localparam A4_VIB_STEP = 18;
     localparam A4_VIB_UP = A4 - 8*A4_VIB_STEP;
     localparam A4_VIB_DOWN = A4 + 8*A4_VIB_STEP;

     localparam B4_VIB_STEP = 18;
     localparam B4_VIB_UP = B4 - 8*B4_VIB_STEP;
     localparam B4_VIB_DOWN = B4 + 8*B4_VIB_STEP;

     // Number of PWM periods to get staccato at roughly the same times,
     // but without having a massive cycle counter for the exact timing
     localparam C4_STAC_MAX = 1571;
     localparam D4_STAC_MAX = 1764;
     localparam E4_STAC_MAX = 1979;
     localparam F4_STAC_MAX = 2094;
     localparam G4_STAC_MAX = 2352;
     localparam A4_STAC_MAX = 2638;
     localparam B4_STAC_MAX = 2963;

     input reset, clk, enable, valid, high_frequency_pwm_enable, vibrato, staccato;
     input [7:0] scancode;
     input [2:0] note_loaded;
     input [PWM_COUNTER_WIDTH-1:0] high_frequency_pwm_counter_init;
     output pwm;

     reg [PWM_COUNTER_WIDTH-1:0] period_counter;
     reg [PWM_COUNTER_WIDTH-1:0] high_frequency_pwm_counter;
     reg [PWM_COUNTER_WIDTH-1:0] step, bound_up, bound_down;
     reg [PWM_COUNTER_WIDTH-1:0] stac_max_count, stac_counter;
     reg [2:0] note_loaded;
     reg up_count, pwm_sample, pwm_internal, valid_delayed;

     wire [PWM_COUNTER_WIDTH-1:0] vib_downwards, vib_upwards;
     wire pwm_rose;

     always @(posedge reset or posedge clk) begin
          if (reset) valid_delayed <= 1'b0;
          else valid_delayed <= valid;
     end


     // Vibrato steps / bounds and staccato cut lengths
     always @(note_loaded or step or bound_up or bound_down) begin
          case (note_loaded)
               0: begin
                    step = 0;
                    bound_up = 0;
                    bound_down = 0;
                    stac_max_count = 0;
               end
               1: begin
                    step = C4_VIB_STEP;
                    bound_up = C4_VIB_UP;
                    bound_down = C4_VIB_DOWN;
                    stac_max_count = C4_STAC_MAX;
               end
               2: begin
                    step = D4_VIB_STEP;
                    bound_up = D4_VIB_UP;
                    bound_down = D4_VIB_DOWN;
                    stac_max_count = D4_STAC_MAX;
               end
               3: begin
                    step = E4_VIB_STEP;
                    bound_up = E4_VIB_UP;
                    bound_down = E4_VIB_DOWN;
                    stac_max_count = E4_STAC_MAX;
               end
               4: begin
                    step = F4_VIB_STEP;
                    bound_up = F4_VIB_UP;
                    bound_down = F4_VIB_DOWN;
                    stac_max_count = F4_STAC_MAX;
               end
               5: begin
                    step = G4_VIB_STEP;
                    bound_up = G4_VIB_UP;
                    bound_down = G4_VIB_DOWN;
                    stac_max_count = G4_STAC_MAX;
               end
               6: begin
                    step = A4_VIB_STEP;
                    bound_up = A4_VIB_UP;
                    bound_down = A4_VIB_DOWN;
                    stac_max_count = A4_STAC_MAX;
               end
               7: begin
                    step = B4_VIB_STEP;
                    bound_up = B4_VIB_UP;
                    bound_down = B4_VIB_DOWN;
                    stac_max_count = B4_STAC_MAX;
               end
               default: begin
                    step = 0;
                    bound_up = 0;
                    bound_down = 0;
                    stac_max_count = 0;
               end
          endcase
     end

     // Adder and subtractor to implement the according oscillation for vibrato
     assign vib_downwards = high_frequency_pwm_counter - step;
     assign vib_upwards = high_frequency_pwm_counter + step;

     // Create output pulse
     always @(posedge reset or posedge clk) begin
          if (reset) begin
               pwm_internal <= 0;
               period_counter <= 0;
               pwm_sample <= 1'b0;
          end
          else if (enable) begin
               if (high_frequency_pwm_enable) begin
                    pwm_sample <= pwm_internal;
                    if (period_counter == high_frequency_pwm_counter) begin
                         pwm_internal <= ~pwm_internal;
                         period_counter <= 0;
                    end
                    else period_counter <= period_counter + 1;
               end
          end
     end

     // Sampling to see rising edge of PWM
     assign pwm_rose = ~pwm_sample & pwm_internal;

     // Vibrato logic
     always @(posedge reset or posedge clk) begin
          if (reset) begin
               high_frequency_pwm_counter <= 0;
               up_count <= 1'b1;
          end
          else if (enable) begin
               if (valid_delayed) high_frequency_pwm_counter <= high_frequency_pwm_counter_init;
               else if (high_frequency_pwm_enable) begin
                    if (vibrato) begin
                         if (pwm_rose) begin
                              high_frequency_pwm_counter <= (up_count) ? vib_upwards : vib_downwards;
                         end
                    end
               end
          end
     end

     // Staccato logic
     assign cut_audio = stac_counter == stac_max_count;
     always @(posedge reset or posedge clk) begin
          if (reset) stac_counter <= 0;
          else if (enable) begin
               if (valid_delayed) stac_counter <= 0;
               else if (high_frequency_pwm_enable) begin
                    if (staccato) begin
                         if (pwm_rose) begin
                              stac_counter <= (cut_audio) ? stac_counter : stac_counter + 1;
                         end
                    end
               end
          end
     end

     assign pwm = (cut_audio) ? 1'b0 : pwm_internal;


endmodule
