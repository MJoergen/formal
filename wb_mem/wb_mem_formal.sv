`default_nettype none

module wb_mem_formal #(
   parameter G_ADDR_SIZE = 8,
   parameter G_DATA_SIZE = 16
   )(
   input  wire                   clk_i,
   input  wire                   rst_i,
   input  wire                   wb_cyc_i,
   output wire                   wb_stall_o,
   input  wire                   wb_stb_i,
   output reg                    wb_ack_o,
   input  wire                   wb_we_i,
   input  wire [G_ADDR_SIZE-1:0] wb_addr_i,
   input  wire [G_DATA_SIZE-1:0] wb_data_i,
   output reg  [G_DATA_SIZE-1:0] wb_data_o
);

   // Instantiate the DUT
   wb_mem DUT (.*); // This only works as long as the port signal names are unchanged.

`ifdef FORMAL // This is set when passing the option "-formal" to the read command in the .sby file.

`ifdef WB_MEM   // This is set with the option "-D WB_MEM".
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

   wire [3:0] f_nreqs, f_nacks, f_outstanding;

   // Formally verify the wishbone protocol
   fwb_slave #(
      .AW(G_ADDR_SIZE),
      .DW(G_DATA_SIZE),
      .F_MAX_ACK_DELAY(1)  // The response always appears on the exact following clock cycle
   ) f_wbs(clk_i, rst_i,
      wb_cyc_i, wb_stb_i, wb_we_i, wb_addr_i, wb_data_i, 2'b11,
      wb_ack_o, wb_stall_o, wb_data_o, 1'b0,
      f_nreqs, f_nacks, f_outstanding);


   /****************************
    * ASSERTIONS ABOUT OUTPUTS
    ****************************/

   // We have no more than a single outstanding request at any given time
   always @(posedge clk_i)
   begin
      if (wb_ack_o && wb_cyc_i)
         assert(f_outstanding == 1);
      else
         assert(f_outstanding == 0);
   end

   // When wb_ack_o is de-asserted, then wb_data_o is all zeros.
   always @(posedge clk_i)
   begin
      if (!wb_ack_o)
         assert (wb_data_o == 0);
   end

   // When writing to memory, the data output is unchanged.
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(wb_cyc_i) && $past(wb_stb_i) && $past(wb_we_i))
         assert ($stable(wb_data_o));
   end

   (* anyconst *) wire [G_ADDR_SIZE-1:0] f_const_addr;
   reg [G_DATA_SIZE-1:0] f_mem_value;

   reg f_mem_valid;
   initial f_mem_valid = 1'b0;

   always @(posedge clk_i)
   begin
      if (wb_cyc_i && wb_stb_i && !wb_stall_o && wb_we_i && (wb_addr_i == f_const_addr))
      begin
         f_mem_value <= wb_data_i;
         f_mem_valid <= 1;
      end
   end

   always @(posedge clk_i)
   begin
      if (f_past_valid && f_mem_valid && $past(wb_cyc_i) && $past(wb_stb_i) && $past(!wb_stall_o) && $past(!wb_we_i) && $past(wb_addr_i == f_const_addr))
         assert (wb_data_o == f_mem_value);
   end

`endif // FORMAL

endmodule : wb_mem_formal

