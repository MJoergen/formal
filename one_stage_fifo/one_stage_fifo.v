`default_nettype none

// This module implements a FIFO consisting of only a single register layer.
// It has its use in elastic pipelines, where the data flow has back-pressure.
// It places registers on the valid and data signals in the downstream direction,
// but the ready signal in the upstream direction is still combinatorial.

// Formal verification is done using yosys, which can be found here: https://github.com/YosysHQ/SymbiYosys
// A nice introduction is here: http://zipcpu.com/blog/2017/10/19/formal-intro.html

module one_stage_fifo #(
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

   reg                   m_valid_r;
   reg [G_DATA_SIZE-1:0] m_data_r;

   assign s_ready_o = m_ready_i || !m_valid_r;

   always @(posedge clk_i)
   begin
      // Downstream has consumed the output
      if (m_ready_i)
      begin
         m_valid_r <= 0;
      end

      // Valid data on the input
      if (s_ready_o && s_valid_i)
      begin
         m_data_r  <= s_data_i;
         m_valid_r <= 1;
      end

      // Reset
      if (rst_i)
      begin
         m_valid_r <= 0;
      end
   end

   assign m_valid_o = m_valid_r;
   assign m_data_o  = m_data_r;


`ifdef FORMAL

// This is necessary, because the $past() function returns uninitialized value on the first clock cycle.
   reg past_valid;
   initial past_valid = 0;
   always @(posedge clk_i)
      past_valid <= 1;

// Validate input (using assume)
   always @(posedge clk_i)
   begin
      if (past_valid && !rst_i)
      begin
         if ($past(s_valid_i) && $past(!s_ready_o))
         begin
            assume ($stable(s_valid_i));  // s_valid_i must the same as the last clock cycle
            assume ($stable(s_data_i));   // s_data_i must the same as the last clock cycle
         end
      end
   end

// Validate output (using assert)
   always @(posedge clk_i)
   begin
      if (past_valid && $past(!rst_i))
      begin
         if ($past(m_valid_o) && $past(!m_ready_i))
         begin
            assert ($stable(m_valid_o));  // m_valid_o must the same as the last clock cycle
            assert ($stable(m_data_o));   // m_data_o must the same as the last clock cycle
         end
      end
   end

// Validate reset (using assert)
   always @(posedge clk_i)
   begin
      if (past_valid && $fell(rst_i))
      begin
         assert (m_valid_o == 0);          // m_data_o must be cleared after reset
      end
   end

// Make sure all states are exercised (using cover)
generate
   genvar i;
   for (i=0; i < 8; i++) begin: CVR
      always @(posedge clk_i)
      begin
         cover (past_valid && !rst_i && {s_valid_i, m_ready_i, m_valid_o} == i);
      end
   end
endgenerate

`endif

endmodule: one_stage_fifo

