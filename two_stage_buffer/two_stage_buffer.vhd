-- An elastic pipeline with two stages, with zero latency.
-- It can accept two writes before blocking, i.e. a FIFO of depth two.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity two_stage_buffer is
   generic (
      G_DATA_SIZE : integer := 8
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_fill_o  : out std_logic_vector(1 downto 0);
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity two_stage_buffer;

architecture synthesis of two_stage_buffer is

   signal int_valid : std_logic;
   signal int_ready : std_logic;
   signal int_data  : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal int_afull : std_logic;
   signal s_afull   : std_logic;

begin

   s_fill_o <= "00" when not int_afull else
               "01" when not s_afull else
               "10";

   i_osb_first : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => s_valid_i,
         s_ready_o => s_ready_o,
         s_data_i  => s_data_i,
         s_afull_o => s_afull,
         m_valid_o => int_valid,
         m_ready_i => int_ready,
         m_data_o  => int_data
      ); -- i_osb_first

   i_osb_second : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => int_valid,
         s_ready_o => int_ready,
         s_data_i  => int_data,
         s_afull_o => int_afull,
         m_valid_o => m_valid_o,
         m_ready_i => m_ready_i,
         m_data_o  => m_data_o
      ); -- i_osb_second

end architecture synthesis;

