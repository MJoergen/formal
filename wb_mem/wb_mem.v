`default_nettype none

// A simple memory with a Wishbone Slave interface
// * When wb_ack_o is de-asserted, then wb_data_o is all zeros.
// * The response always appears on the exact following clock cycle.
// * We have no more than a single outstanding request at any given time.

module wb_mem #(
   parameter G_ADDR_SIZE = 8,
   parameter G_DATA_SIZE = 16
   )(
   input  wire                   clk_i,
   input  wire                   rst_i,
   input  wire                   wb_cyc_i,
   output wire                   wb_stall_o,
   input  wire                   wb_stb_i,
   output reg                    wb_ack_o = 0,
   input  wire                   wb_we_i,
   input  wire [G_ADDR_SIZE-1:0] wb_addr_i,
   input  wire [G_DATA_SIZE-1:0] wb_data_i,
   output reg  [G_DATA_SIZE-1:0] wb_data_o = 0
);

   // The actual memory itself
   reg [G_DATA_SIZE-1:0] mem [0:2**G_ADDR_SIZE-1];

   // Combinatorial outputs
   assign wb_stall_o = rst_i;

   // Writing to memory
   always @(posedge clk_i)
   begin
      if (wb_cyc_i && wb_stb_i && ~wb_stall_o && wb_we_i)
      begin
         mem[wb_addr_i] <= wb_data_i;
      end
   end

   // Reading from memory
   always @(posedge clk_i)
   begin
      wb_data_o <= 0;
      wb_ack_o  <= 0;
      if (wb_cyc_i && wb_stb_i && ~wb_stall_o)
      begin
         wb_data_o <= mem[wb_addr_i];
         wb_ack_o  <= 1;
      end
   end

`ifdef FORMAL
   wire  [3:0] f_nreqs, f_nacks, f_outstanding;

   // Formally verify the wishbone protocol
   fwb_slave #(
      .AW(G_ADDR_SIZE),
      .DW(G_DATA_SIZE),
      .F_MAX_ACK_DELAY(1)  // The response always appears on the exact following clock cycle
   ) f_wbs(clk_i, rst_i,
      wb_cyc_i, wb_stb_i, wb_we_i, wb_addr_i, wb_data_i, 2'b11,
      wb_ack_o, wb_stall_o, wb_data_o, 1'b0,
      f_nreqs, f_nacks, f_outstanding);

   // We have no more than a single outstanding request at any given time
   always @(posedge clk_i)
   if (wb_ack_o && wb_cyc_i)
      assert(f_outstanding == 1);
   else
      assert(f_outstanding == 0);

   // When wb_ack_o is de-asserted, then wb_data_o is all zeros.
   always @(posedge clk_i)
   if (!wb_ack_o)
      assert (wb_data_o == 0);
`endif

endmodule : wb_mem

