-------------------------------------------------------------------------------
-- Description:
-- This module inserts a pipeline delay of one clock cycle into the AXI stream.
-- This breaks the combinatorial path on the data signals, but there is still
-- a combinatorial path of the ready signal.
-- If you need a register of the ready signal, then use the axi_pipe module.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity axi_pipe_small is
   generic (
      G_TDATA_SIZE : integer := 32
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Input
      s_tvalid_i : in  std_logic;
      s_tready_o : out std_logic;
      s_tdata_i  : in  std_logic_vector(G_TDATA_SIZE-1 downto 0);

      -- Output
      m_tvalid_o : out std_logic;
      m_tready_i : in  std_logic;
      m_tdata_o  : out std_logic_vector(G_TDATA_SIZE-1 downto 0)
   );
end entity axi_pipe_small;

architecture synthesis of axi_pipe_small is

   -- Input registers
   signal s_tvalid_r : std_logic := '0';
   signal s_tdata_r  : std_logic_vector(G_TDATA_SIZE-1 downto 0);

begin

   -- This introduces a combinatorial path from m_tready_i to s_tready_o.
   s_tready_o <= '1' when s_tvalid_r = '0' else
                 m_tready_i;


   -----------------
   -- State machine
   -----------------

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Check if output is consumed
         if m_tready_i = '1' then
            s_tvalid_r <= '0';
         end if;

         if s_tready_o = '1' then
            -- Ready is already asserted, so we have to accept the data
            s_tvalid_r <= s_tvalid_i;
            s_tdata_r  <= s_tdata_i;
         end if;

         if rst_i = '1' then
            s_tvalid_r <= '0';
         end if;
      end if;
   end process p_fsm;


   --------------------------
   -- Connect output signals
   --------------------------

   m_tvalid_o <= s_tvalid_r;
   m_tdata_o  <= s_tdata_r;

end architecture synthesis;

