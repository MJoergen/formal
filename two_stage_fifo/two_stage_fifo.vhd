-- An elastic pipeline with two stages. I.e. can accept two writes before blocking.
-- In other words, a FIFO of depth two.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity two_stage_fifo is
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
end entity two_stage_fifo;

architecture synthesis of two_stage_fifo is

   -- Input registers
   signal s_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- Output registers
   signal m_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- Control signals
   signal s_ready_r : std_logic := '1';
   signal m_valid_r : std_logic := '0';

begin

   s_fill_o <= "00" when m_valid_o = '0' else
               "01" when m_valid_o = '1' and s_ready_o = '1' else
               "10"; --  when m_valid_o = '1' and s_ready_o = '0'


   p_s_data : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_ready_r = '1' then
            s_data_r  <= s_data_i;
         end if;
      end if;
   end process p_s_data;


   p_s_ready : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_valid_r = '1' then
            s_ready_r <= m_ready_i or (s_ready_r and not s_valid_i);
         end if;

         if rst_i = '1' then
            s_ready_r <= '1';
         end if;
      end if;
   end process p_s_ready;


   p_m : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_ready_r = '1' then
            if m_valid_r = '0' or m_ready_i = '1' then
               m_valid_r <= s_valid_i;
               m_data_r  <= s_data_i;
            end if;
         else
            if m_ready_i = '1' then
               m_data_r  <= s_data_r;
            end if;
         end if;

         if rst_i = '1' then
            m_valid_r <= '0';
         end if;
      end if;
   end process p_m;


   --------------------------
   -- Connect output signals
   --------------------------

   s_ready_o <= s_ready_r;
   m_valid_o <= m_valid_r;
   m_data_o  <= m_data_r;

end architecture synthesis;

