// This file contains all the formal properties of the FETCH module

`default_nettype none

module fetch_formal(
   // The interface must be identical to the VHDL module.
   input  wire        clk_i,
   input  wire        rst_i,

   // Send read request to WISHBONE
   output wire        wb_cyc_o,
   output wire        wb_stb_o,
   input  wire        wb_stall_i,
   output wire [15:0] wb_addr_o,

   // Receive read response from WISHBONE
   input  wire        wb_ack_i,
   input  wire [15:0] wb_data_i,

   // Send instruction to DECODE
   output wire        dc_valid_o,
   input  wire        dc_ready_i,
   output wire [15:0] dc_addr_o,
   output wire [15:0] dc_data_o,

   // Receive a new PC from DECODE
   input  wire        dc_valid_i,
   input  wire [15:0] dc_addr_i);

   // Instantiate the FETCH module
   fetch DUT (.*); // This only works as long as the port signal names are unchanged.

`ifdef FETCH
`define ASSUME assume
`else
`define ASSUME assert
`endif

   // This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
   reg f_past_valid;
   initial f_past_valid = 1'b0;
   always @(posedge clk_i)
      f_past_valid <= 1'b1;


   // Require reset at startup.
   // This is to ensure BMC starts in a valid state.
   initial `ASSUME(rst_i);


   /**************************************
    * VERIFICATION OF WISHBONE INTERFACE
    **************************************/

   wire [3:0] f_nreqs;
   wire [3:0] f_nacks;
   wire [3:0] f_outstanding;

   fwb_master #(
      .AW                   (16),
      .DW                   (16),
      .F_MAX_STALL          (4),
      .F_OPT_SOURCE         (1),
      .F_OPT_RMW_BUS_OPTION (0),
      .F_OPT_DISCONTINUOUS  (1)
   )
   f_wbm (
      .i_clk         (clk_i),
      .i_reset       (rst_i),
      .i_wb_cyc      (wb_cyc_o),
      .i_wb_stb      (wb_stb_o),
      .i_wb_we       (1'b0),
      .i_wb_addr     (wb_addr_o),
      .i_wb_data     (16'h0000),
      .i_wb_sel      (4'h0),
      .i_wb_ack      (wb_ack_i),
      .i_wb_stall    (wb_stall_i),
      .i_wb_data     (wb_data_i),
      .i_wb_err      (1'b0),
      .f_nreqs       (f_nreqs),
      .f_nacks       (f_nacks),
      .f_outstanding (f_outstanding)
   ); // fwb_master

   // Here we re-state that we have no more than a single outstanding request
   // at any given time.  The formal prover can verify the correctness of this
   // assertion, and subsequenly use this is the induction step.
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(wb_cyc_o) && $past(wb_ack_i))
         assert (f_outstanding == 0);
      assert(f_outstanding <= 1);
   end


   /**************************************
    * ASSERTIONS ABOUT OUTPUTS TO DECODE
    **************************************/

   // As long as we're not receiving a new PC, keep the output
   // to the DECODE stage stable until accepted.
   always @(posedge clk_i) begin
      if (f_past_valid && $past(!rst_i) && $past(!dc_valid_i) && $past(dc_valid_o) && $past(!dc_ready_i))
      begin
         assert ($stable(dc_valid_o));
         assert ($stable(dc_addr_o));
         assert ($stable(dc_data_o));
      end
   end

   // After a new address is received, data to the DECODE stage is
   // invalidated.
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(dc_valid_i))
      begin
         assert (!dc_valid_o);
      end
   end

   // Valid data is presented to DECODE immediately after receiving
   // from wishbone
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(!rst_i) && $past(wb_cyc_o) && $past(wb_ack_i) && $past(!dc_valid_i))
      begin
         assert (dc_valid_o);
      end
   end


   /********************
    * COVER STATEMENTS
    ********************/

   // DECODE stage accepts data
   always @(posedge clk_i)
   begin
      cover (f_past_valid && $past(dc_valid_o) && !dc_valid_o);
   end

   // DECODE stage receives two data cycles back-to-back
   always @(posedge clk_i)
   begin
      cover (f_past_valid && $past(dc_valid_o) && $past(dc_ready_i) && dc_valid_o);
   end

   always @(posedge clk_i)
   begin
      cover (f_past_valid && $past(dc_valid_o) && $past(!dc_ready_i) && $past(wb_cyc_o) && $past(wb_ack_i) && dc_ready_i);
   end

endmodule : fetch_formal

