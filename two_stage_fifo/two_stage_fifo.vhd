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

   s_fill_o <= "00" when m_valid_o = '0' and s_ready_o = '1' else
               "01" when m_valid_o = '1' and s_ready_o = '1' else
               "10" when m_valid_o = '1' and s_ready_o = '0' else
               "11";

   -----------------
   -- State machine
   -----------------

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case s_fill_o is
            when "00" =>
               if s_valid_i = '1' then
                  -- Ready is already asserted, so we have to accept the data
                  m_data_r  <= s_data_i;

                  m_valid_r <= '1';
               end if;

            when "01" =>
               -- The pipe has valid data in m_*
               case std_logic_vector'(m_ready_i & s_valid_i) is
                  when "00" =>
                     null;

                  when "01" =>
                     -- Increase pipeline
                     s_data_r  <= s_data_i;
                     s_ready_r <= '0';

                  when "10" =>
                     -- Decrease pipeline
                     m_valid_r <= '0';

                  when "11" =>
                     m_data_r  <= s_data_i;

                  when others => null;
               end case;

            when "10" =>
               -- The pipe has valid data in both s_* and m_*
               if m_ready_i = '1' then
                  -- Valid is asserted, so data has been accepted
                  m_data_r  <= s_data_r;

                  s_ready_r <= '1';
               end if;

            when others =>
               s_ready_r <= '1';
               m_valid_r <= '0';

         end case;

         if rst_i = '1' then
            s_ready_r <= '1';
            m_valid_r <= '0';
         end if;
      end if;
   end process p_fsm;


   --------------------------
   -- Connect output signals
   --------------------------

   s_ready_o <= s_ready_r;
   m_valid_o <= m_valid_r;
   m_data_o  <= m_data_r;

end architecture synthesis;

