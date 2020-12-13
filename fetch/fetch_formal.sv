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
   output wire [15:0] dc_inst_o,

   // Receive a new PC from DECODE
   input  wire        dc_valid_i,
   input  wire [15:0] dc_pc_i);

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


   /****************************************
    * ASSUMPTIONS ABOUT INPUTS FROM DECODE
    ****************************************/

   // Require reset at startup
   initial `ASSUME(rst_i);

   // The DECODE stage is expected to assert dc_valid_i right after a reset.
   always @(posedge clk_i)
      if (f_past_valid && $past(rst_i))
         `ASSUME(dc_valid_i);

   // The DECODE stage is expected to be ready right after a reset.
   always @(posedge clk_i)
      if (f_past_valid && $past(rst_i))
         `ASSUME(dc_ready_i);

   // The DECODE stage is expected to stay ready when no output.
   always @(posedge clk_i)
      if (f_past_valid && $past(dc_ready_i) && $past(!dc_valid_o))
         `ASSUME(dc_ready_i);

   // Count the number of clock cycles the DECODE stage is stalling.
   reg f_decode_stall;
   always @(posedge clk_i)
   begin
      if (dc_valid_o && !dc_ready_i)
         f_decode_stall <= f_decode_stall + 1;
      else
         f_decode_stall <= 0;
   end

   // Maximum number of clock cycles the DECODE stage may stall.
   localparam F_DECODE_STALL_MAX = 4;

   // Make sure the DECODE stage does not stall for too long.
   always @(posedge clk_i)
      assume (f_decode_stall < F_DECODE_STALL_MAX);


   /**************************************
    * VERIFICATION OF WISHBONE INTERFACE
    **************************************/

   wire [3:0] f_nreqs;
   wire [3:0] f_nacks;
   wire [3:0] f_outstanding;

   fwb_master #(
      .AW                   (16),
      .DW                   (16),
      .F_LGDEPTH            (4),
      .F_MAX_REQUESTS       (1),
      .F_OPT_SOURCE         (1),
      .F_OPT_RMW_BUS_OPTION (0),
      .F_OPT_DISCONTINUOUS  (0)
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


   /**************************************
    * ASSERTIONS ABOUT OUTPUTS TO DECODE
    **************************************/

   // The output to the DECODE stage must be stopped when accepted.
   // This essentially states that the DECODE stage will receive valid
   // instructions at most every second clock cycle.
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(dc_valid_o) && $past(dc_ready_i))
      begin
         assert (!dc_valid_o);
      end
   end

   // The output to the DECODE stage should be stable while valid
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(dc_valid_o) && dc_valid_o)
      begin
         assert ($stable(dc_addr_o));   // dc_addr_o must be the same as the last clock cycle
         assert ($stable(dc_inst_o));   // dc_inst_o must be the same as the last clock cycle
      end
   end

   // As long as we're not receiving a new PC, keep the output
   // to the DECODE stage stable until accepted.
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(!rst_i) && $past(!dc_valid_i) && $past(dc_valid_o) && $past(!dc_ready_i))
      begin
         assert ($stable(dc_valid_o));
         assert ($stable(dc_addr_o));
         assert ($stable(dc_inst_o));
      end
   end

   // While reading from wishbone, no output to the DECODE stage is allowed.
   // The reason is that data received from the WISHBONE has no where to be
   // stored, while another instruction is already presented to the DECODE
   // stage.
   always @(posedge clk_i)
   begin
      if (wb_cyc_o)
      begin
         assert (!dc_valid_o);
      end
   end

   // A valid instruction is presented to DECODE immediately after receiving
   // from wishbone
   always @(posedge clk_i)
   begin
      if (f_past_valid && $past(!rst_i) && $past(wb_cyc_o) && $past(wb_ack_i))
      begin
         assert (dc_valid_o);
      end
   end

   // Verify DECUDE stage can accept an instruction
   always @(posedge clk_i)
   begin
      cover (f_past_valid && $past(!rst_i) && $past(dc_valid_o) && !dc_valid_o);
   end

endmodule : fetch_formal

