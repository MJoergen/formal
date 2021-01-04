library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This is a simple buffer that is transparent (combinatorial) when the
-- receiver is ready, but registers the incoming value if not.

entity one_stage_buffer is
   generic (
      G_DATA_SIZE : integer := 8
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_afull_o : out std_logic;
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity one_stage_buffer;

architecture synthesis of one_stage_buffer is

   signal s_ready_s : std_logic;
   signal m_valid_r : std_logic := '0';
   signal m_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   -- We accept data from upstream in two situations:
   -- * When FIFO is empty.
   -- * When downstream is ready.
   -- The latter situation allows simultaneous read and write, even when the
   -- FIFO is full.
   s_ready_s <= m_ready_i or not m_valid_r;

   p_buffer : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Downstream has consumed the output
         if m_ready_i = '1' and s_valid_i = '0' then
            m_valid_r <= '0';
         end if;

         -- Valid data on the input
         if s_ready_s = '1' and s_valid_i = '1' then
            m_data_r  <= s_data_i;
         end if;

         -- Store in buffer
         if m_ready_i = '0' and s_valid_i = '1' then
            m_valid_r <= '1';
         end if;

         -- Reset empties the FIFO
         if rst_i = '1' then
            m_valid_r <= '0';
         end if;
      end if;
   end process p_buffer;

   -- Connect output signals
   s_afull_o <= m_valid_r;
   s_ready_o <= s_ready_s;
   m_data_o  <= m_data_r when m_valid_r = '1' else s_data_i;
   m_valid_o <= m_valid_r or (s_valid_i and not rst_i);

end architecture synthesis;

