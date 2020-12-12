`default_nettype none

// This file contains all the formal verification of the one_stage_fifo unit.

// All the port names must match identically to that of the DUT.
// Appending "_formal" to the module name is just a naming convention.
module one_stage_fifo_formal #(
   parameter G_DATA_SIZE = 8
   )(
   input  wire                   clk_i,
   input  wire                   rst_i,
   input  wire                   s_valid_i,
   output wire                   s_ready_o,
   input  wire [G_DATA_SIZE-1:0] s_data_i,
   output wire                   m_valid_o,
   input  wire                   m_ready_i,
   output wire [G_DATA_SIZE-1:0] m_data_o
);

   // Instantiate the DUT module
   one_stage_fifo DUT (.*); // This only works as long as the port signal names are unchanged.

`ifdef FORMAL // This is set when passing the option "-formal" to the read command in the .sby file.

`ifdef ONE_STAGE_FIFO   // This is set with the option "-D ONE_STAGE_FIFO".
`define ASSUME assume
`else
`define ASSUME assert
`endif

   // This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
   reg f_past_valid;
   initial f_past_valid = 1'b0;
   always @(posedge clk_i)
      f_past_valid <= 1'b1;


   /****************************
    * ASSUMPTIONS ABOUT INPUTS
    ****************************/

   // Require reset at startup
   initial `ASSUME(rst_i);

   // Input must be stable until accepted
   always @(posedge clk_i)
   begin
      if (f_past_valid && !rst_i && $past(s_valid_i) && $past(!s_ready_o))
      begin
         `ASSUME ($stable(s_valid_i));
         `ASSUME ($stable(s_data_i));
      end
   end


   /****************************
    * ASSERTIONS ABOUT OUTPUTS
    ****************************/

   // FIFO must be empty after reset
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(rst_i))
      begin
         assert (m_valid_o == 0);
      end
   end

   // Output must be stable until accepted
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(!rst_i) && $past(m_valid_o) && $past(!m_ready_i))
      begin
         assert ($stable(m_valid_o));
         assert ($stable(m_data_o));
      end
   end

   // Output must be invalid when FIFO is empty
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(m_valid_o) && $past(m_ready_i) && $past(!s_valid_i))
      begin
         assert (!m_valid_o);
      end
   end


   /*******************************************
    * COVER STATEMENTS TO VERIFY REACHABILITY
    *******************************************/

   // Make sure all states are exercised (using cover)
   generate
      genvar i;
      for (i=0; i < 8; i++) begin: CVR
         always @(posedge clk_i)
         begin
            cover (f_past_valid && $past(!rst_i) && {s_valid_i, m_ready_i, m_valid_o} == i);
         end
      end
   endgenerate

`endif // FORMAL

endmodule: one_stage_fifo_formal

