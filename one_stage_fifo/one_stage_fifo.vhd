library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module implements a FIFO consisting of only a single register layer.
-- It has its use in elastic pipelines, where the data flow has back-pressure.
-- It places registers on the valid and data signals in the downstream direction,
-- but the ready signal in the upstream direction is still combinatorial.
-- The FIFO supports simultaneous read and write, both when the FIFO is full
-- and when it is empty.
--
-- For additional information, see:
-- https://www.itdev.co.uk/blog/pipelining-axi-buses-registered-ready-signals

entity one_stage_fifo is
   generic (
      G_DATA_SIZE : integer := 8
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity one_stage_fifo;

architecture synthesis of one_stage_fifo is

   signal s_ready_s : std_logic;
   signal m_valid_r : std_logic;
   signal m_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

   -- We accept data from upstream in two situations:
   -- * When FIFO is empty.
   -- * When downstream is ready.
   -- The latter situation allows simultaneous read and write, even when the
   -- FIFO is full.
   s_ready_s <= m_ready_i or not m_valid_r;

   p_fifo : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_ready_s then
            m_data_r  <= s_data_i;
            m_valid_r <= s_valid_i;
         end if;

         -- Reset empties the FIFO
         if rst_i = '1' then
            m_valid_r <= '0';
         end if;
      end if;
   end process p_fifo;

   -- Connect output signals
   s_ready_o <= s_ready_s;
   m_valid_o <= m_valid_r;
   m_data_o  <= m_data_r;

end architecture synthesis;

