// This file contains all the formal properties of the FETCH module

`default_nettype none

module rubik_formal(
   // The interface must be identical to the VHDL module.
   input  wire       clk_i,
   input  wire       rst_i,
   input  wire [3:0] cmd_i,
   output wire [2:0] u0_o,
   output wire [2:0] u1_o,
   output wire [2:0] u2_o,
   output wire [2:0] u3_o,
   output wire [2:0] f0_o,
   output wire [2:0] f1_o,
   output wire [2:0] f2_o,
   output wire [2:0] f3_o,
   output wire [2:0] r0_o,
   output wire [2:0] r1_o,
   output wire [2:0] r2_o,
   output wire [2:0] r3_o,
   output wire [2:0] d0_o,
   output wire [2:0] d1_o,
   output wire [2:0] d2_o,
   output wire [2:0] d3_o,
   output wire [2:0] b0_o,
   output wire [2:0] b1_o,
   output wire [2:0] b2_o,
   output wire [2:0] b3_o,
   output wire [2:0] l0_o,
   output wire [2:0] l1_o,
   output wire [2:0] l2_o,
   output wire [2:0] l3_o,
   output wire       done_o
);

   // Instantiate the FETCH module
   rubik DUT (.*); // This only works as long as the port signal names are unchanged.


   /****************************
    * ASSUMPTIONS ABOUT INPUTS
    ****************************/

   // Require reset at startup.
   // This is to ensure BMC starts in a valid state.
   initial assume(rst_i);


   /****************************
    * ASSERTIONS ABOUT OUTPUTS
    ****************************/

   always @(posedge clk_i)
   begin
      if (!rst_i)
      begin
         assert (u2_o != f0_o);
         assert (u3_o != f1_o);
         assert (l1_o != f0_o);
         assert (l3_o != f2_o);
         assert (d0_o != f2_o);
         assert (d1_o != f3_o);
         assert (r2_o != f3_o);
         assert (r0_o != f1_o);

         assert (u2_o != l1_o);
         assert (u0_o != l0_o);
         assert (l3_o != d0_o);
         assert (l2_o != d2_o);
         assert (d1_o != r2_o);
         assert (d3_o != r3_o);
         assert (r0_o != u3_o);
         assert (r1_o != u1_o);

         assert (r1_o != b0_o);
         assert (r3_o != b2_o);
         assert (d3_o != b2_o);
         assert (d2_o != b3_o);
         assert (u0_o != b1_o);
         assert (u1_o != b0_o);
         assert (b1_o != l0_o);
         assert (b3_o != l2_o);
      end
   end

   wire integer num_colors[0:5];
   wire integer i;

   always @(*)
   begin
      for (i=0; i<6; i=i+1)
      begin
         num_colors[i] = 0;
      end
      num_colors[u0_o] = num_colors[u0_o] + 1;
      num_colors[u1_o] = num_colors[u1_o] + 1;
      num_colors[u2_o] = num_colors[u2_o] + 1;
      num_colors[u3_o] = num_colors[u3_o] + 1;
      num_colors[f0_o] = num_colors[f0_o] + 1;
      num_colors[f1_o] = num_colors[f1_o] + 1;
      num_colors[f2_o] = num_colors[f2_o] + 1;
      num_colors[f3_o] = num_colors[f3_o] + 1;
      num_colors[r0_o] = num_colors[r0_o] + 1;
      num_colors[r1_o] = num_colors[r1_o] + 1;
      num_colors[r2_o] = num_colors[r2_o] + 1;
      num_colors[r3_o] = num_colors[r3_o] + 1;
      num_colors[d0_o] = num_colors[d0_o] + 1;
      num_colors[d1_o] = num_colors[d1_o] + 1;
      num_colors[d2_o] = num_colors[d2_o] + 1;
      num_colors[d3_o] = num_colors[d3_o] + 1;
      num_colors[b0_o] = num_colors[b0_o] + 1;
      num_colors[b1_o] = num_colors[b1_o] + 1;
      num_colors[b2_o] = num_colors[b2_o] + 1;
      num_colors[b3_o] = num_colors[b3_o] + 1;
      num_colors[l0_o] = num_colors[l0_o] + 1;
      num_colors[l1_o] = num_colors[l1_o] + 1;
      num_colors[l2_o] = num_colors[l2_o] + 1;
      num_colors[l3_o] = num_colors[l3_o] + 1;
   end

   always @(posedge clk_i)
   begin
      if (!rst_i)
      begin
         assert (num_colors[0] == 4);
         assert (num_colors[1] == 4);
         assert (num_colors[2] == 4);
         assert (num_colors[3] == 4);
         assert (num_colors[4] == 4);
         assert (num_colors[5] == 4);
      end
   end


   /********************
    * COVER STATEMENTS
    ********************/

   // DECODE stage accepts data (trace 1)
   always @(posedge clk_i)
   begin
      cover (!rst_i && done_o);
   end

endmodule : rubik_formal

