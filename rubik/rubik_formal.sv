// This file contains all the formal properties of the FETCH module

`default_nettype none

module rubik_formal(
   // The interface must be identical to the VHDL module.
   input  wire       clk_i,
   input  wire       rst_i,
   input  wire [3:0] cmd_i,
   output wire       done_o);

   // Instantiate the FETCH module
   rubik DUT (.*); // This only works as long as the port signal names are unchanged.

   // This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
   reg f_past_valid;
   initial f_past_valid = 1'b0;
   always @(posedge clk_i)
      f_past_valid <= 1'b1;


   /****************************
    * ASSUMPTIONS ABOUT INPUTS
    ****************************/

   // Require reset at startup.
   // This is to ensure BMC starts in a valid state.
   initial assume(rst_i);


   /********************
    * COVER STATEMENTS
    ********************/

   // DECODE stage accepts data (trace 1)
   always @(posedge clk_i)
   begin
      cover (!rst_i && done_o);
   end

endmodule : rubik_formal

