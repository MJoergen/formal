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
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity one_stage_buffer;

architecture synthesis of one_stage_buffer is

   signal s_ready_s : std_logic;
   signal s_valid_r : std_logic := '0';
   signal s_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   s_ready_s <= m_ready_i or not s_valid_r;

   p_buffer : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            -- Receiver has consumed output
            s_valid_r <= '0';
         end if;

         if s_valid_i = '1' and s_valid_r <= '0' and m_ready_i = '0' then
            s_valid_r <= '1';
            s_data_r  <= s_data_i;
         end if;

         if rst_i = '1' then
            s_valid_r <= '0';
         end if;
      end if;
   end process p_buffer;

   -- Connect output signals
   s_ready_o <= s_ready_s;
   m_data_o  <= s_data_r when s_valid_r = '1' else s_data_i;
   m_valid_o <= (s_valid_r or s_valid_i) and not rst_i;

end architecture synthesis;

