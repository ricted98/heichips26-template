module note_storage (reset, clk, valid, recycle, shift, load, parallel_in, neighbor_in, note_scancode);

     input reset, clk, valid, recycle, shift, load;
     input [7:0] parallel_in, neighbor_in;

     output reg [7:0] note_scancode;


     always @(posedge reset or posedge clk) begin
          if (reset) note_scancode <= 8'b0;
          else if (valid) begin
               if (shift) note_scancode <= neighbor_in;
               else if (recycle) note_scancode <= note_scancode;
               else if (load) note_scancode <= parallel_in;
          end
     end


endmodule
