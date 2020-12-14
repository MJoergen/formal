// This file contains all the formal properties of the FETCH module

`default_nettype none

module fgc_formal(
   input  wire       clk_i,
   input  wire       rst_i,
   input  wire [1:0] item_i,
   output wire       bank_f_o,
   output wire       bank_g_o,
   output wire       bank_c_o,
   output wire       bank_m_o
);

   // Instantiate the FETCH module
   fgc DUT (.*); // This only works as long as the port signal names are unchanged.

   // This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
   reg f_past_valid;
   initial f_past_valid = 1'b0;
   always @(posedge clk_i)
      f_past_valid <= 1'b1;


   /****************************************
    * ASSUMPTIONS ABOUT INPUTS FROM DECODE
    ****************************************/

   // Require reset at startup
   initial assume(rst_i);

   // Fox and Goat can not be alone
   always @(posedge clk_i)
      if (bank_f_o == bank_g_o)
         assume(bank_m_o == bank_f_o);

   // Goat and cabbage can not be alone
   always @(posedge clk_i)
      if (bank_g_o == bank_c_o)
         assume(bank_m_o == bank_g_o);

   // Attempt to have everything on bank 1
   always @(posedge clk_i)
      cover (bank_m_o && bank_f_o && bank_g_o && bank_c_o);

endmodule : fgc_formal

