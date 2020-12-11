`default_nettype none

module fetch_vhd(
   input  wire        clk_i,
   input  wire        rst_i,
   output wire        wb_cyc_o,
   output wire        wb_stb_o,
   input  wire        wb_stall_i,
   output wire [15:0] wb_addr_o,
   input  wire        wb_ack_i,
   input  wire [15:0] wb_data_i,
   output wire        dc_valid_o,
   input  wire        dc_ready_i,
   output wire [15:0] dc_addr_o,
   output wire [15:0] dc_inst_o,
   input  wire        dc_valid_i,
   input  wire [15:0] dc_pc_i);

   fetch DUT (.*);

`ifdef FETCH
`define ASSUME assume
`else
`define ASSUME assert
`endif

// Require reset at startup
initial `ASSUME(rst_i);

// This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
reg past_valid;
initial past_valid = 1'b0;
always @(posedge clk_i)
   past_valid <= 1'b1;

// The DECODE stage is expected to assert dc_valid_i after a reset.
always @(posedge clk_i)
   if (past_valid && $past(rst_i))
      `ASSUME(dc_valid_i);

// The output to the DECODE stage should be stable until accepted
   always @(posedge clk_i)
   begin
      if (past_valid && $past(!rst_i))
      begin
         if ($past(dc_valid_o) && $past(!dc_ready_i))
         begin
            assert ($stable(dc_valid_o));  // dc_valid_o must the same as the last clock cycle
            assert ($stable(dc_addr_o));   // dc_addr_o must the same as the last clock cycle
            assert ($stable(dc_inst_o));   // dc_inst_o must the same as the last clock cycle
         end
      end
   end

endmodule

