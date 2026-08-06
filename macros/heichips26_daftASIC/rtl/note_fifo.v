module note_fifo (reset, clk, valid, scancode_in, notes_folded);

     localparam N = 8;

     input reset, clk, valid;
     input [7:0] scancode_in;

     output [N*8-1:0] notes_folded;

     wire [(N+1)*8-1:0] notes_dummy;         // Not actually logic, just for the generate statement
     wire [N-1:0] recycle, load;
     wire shift;


     // Shifting occurs only if normally everything would recycle,
     // in other cases we basically have a thermometer code
     assign shift = &recycle;
     assign notes_folded = notes_dummy[N*8-1:0];
     assign notes_dummy[(N+1)*8-1:N*8] = scancode_in;

     genvar i;
     generate
          for (i = 0; i < N; i = i + 1) begin

               // Recycling happens if there's a non-zero value stored (PS/2 scancodes are never 0x00),
               // and the loading occurs if the current cell is not recycling but the one to its left is
               assign recycle[i] = |notes_folded[(i+1)*8-1 -: 8];
               if (i == 0) assign load[i] = ~recycle[i];
               else assign load[i] = ~recycle[i] & recycle[i-1];

               note_storage storage_instance (
                    reset,
                    clk,
                    valid,
                    recycle[i],
                    shift,
                    load[i],
                    scancode_in,
                    notes_dummy[(i+2)*8-1 -: 8],
                    notes_dummy[(i+1)*8-1 -: 8]
               );
          end
     endgenerate


endmodule
