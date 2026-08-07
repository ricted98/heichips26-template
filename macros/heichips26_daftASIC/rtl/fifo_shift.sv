// Copyright 2026 Riccardo Tedeschi
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

module fifo_shift #(
    parameter N = 8,
    parameter DATA_WIDTH = 3,
    localparam PTR_WIDTH = N > 1 ? $clog2(N) : 1
) (
    input  logic                  clk_i,
    input  logic                  rst_i,
    input  logic                  push_i,
    input  logic [DATA_WIDTH-1:0] data_i,
    input  logic [PTR_WIDTH -1:0] sel_i,
    output logic [DATA_WIDTH-1:0] data_o,
    output logic                  valid_o,
    output logic                  is_last_o
);

enum logic { MODE_FIFO = 1'b0, MODE_SHIFT = 1'b1 } mode_d, mode_q;
logic [PTR_WIDTH-1:0] wr_ptr_d, wr_ptr_q;
logic [N-1:0] valid_d, valid_q;
logic [N-1:0][DATA_WIDTH-1:0] data_array_d, data_array_q;
logic is_escape;

assign is_escape = (data_i == '0);

always_comb begin : fifo_shift_comb
    wr_ptr_d     = wr_ptr_q;
    valid_d      = valid_q;
    mode_d       = mode_q;
    data_array_d = data_array_q;

    if (push_i) begin
        if (is_escape) begin
            data_array_d = {data_i, data_array_q[N-1:1]};
            valid_d = {1'b0, valid_q[N-1:1]};
            mode_d = MODE_FIFO;
            if (wr_ptr_q != '0 && mode_q != MODE_SHIFT)
                wr_ptr_d = wr_ptr_q - 1'b1;
        end else if (mode_q == MODE_FIFO) begin
            data_array_d[wr_ptr_q] = data_i;
            valid_d[wr_ptr_q]      = 1'b1;
            if (wr_ptr_q == PTR_WIDTH'(N-1))
                mode_d = MODE_SHIFT;
            else
                wr_ptr_d = wr_ptr_q + 1'b1;
        end else begin
            data_array_d = {data_i, data_array_q[N-1:1]};
        end
    end
end

always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        wr_ptr_q     <= '0;
        mode_q       <= MODE_FIFO;
        valid_q      <= '0;
        data_array_q <= '0;
    end else begin
        wr_ptr_q     <= wr_ptr_d;
        mode_q       <= mode_d;
        valid_q      <= valid_d;
        data_array_q <= data_array_d;
    end
end

assign valid_o = valid_q[sel_i];
assign data_o = data_array_q[sel_i];

logic [N:0] padded_valid;

assign padded_valid = {1'b0, valid_q};
assign is_last_o    = padded_valid[sel_i+1:sel_i] == 2'b01;

endmodule
