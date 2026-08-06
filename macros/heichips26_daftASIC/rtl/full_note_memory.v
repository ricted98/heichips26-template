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
