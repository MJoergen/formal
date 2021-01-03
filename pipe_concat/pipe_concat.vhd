-- This concatenates two elastic pipelines into one.

library ieee;
use ieee.std_logic_1164.all;

entity pipe_concat is
   generic (
      G_DATA0_SIZE : integer := 8;
      G_DATA1_SIZE : integer := 8
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      s0_valid_i : in  std_logic;
      s0_ready_o : out std_logic;
      s0_data_i  : in  std_logic_vector(G_DATA0_SIZE-1 downto 0);
      s1_valid_i : in  std_logic;
      s1_ready_o : out std_logic;
      s1_data_i  : in  std_logic_vector(G_DATA1_SIZE-1 downto 0);
      m_valid_o  : out std_logic;
      m_ready_i  : in  std_logic;
      m_data_o   : out std_logic_vector(G_DATA0_SIZE+G_DATA1_SIZE-1 downto 0)
   );
end entity pipe_concat;

architecture synthesis of pipe_concat is

begin

   m_data_o <= s1_data_i & s0_data_i;

   m_valid_o  <=               s0_valid_i and s1_valid_i;
   s0_ready_o <= m_ready_i                and s1_valid_i;
   s1_ready_o <= m_ready_i and s0_valid_i;

end architecture synthesis;

