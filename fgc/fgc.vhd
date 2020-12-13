library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A simple demonstration of using formal verification
-- to solve the Fox-Goat-Cabbage problem

entity fgc is
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;

      -- THe boat can only carry one of the three items
      item_i   : in  std_logic_vector(1 downto 0);

      -- Current status
      bank_f_o : out std_logic;
      bank_g_o : out std_logic;
      bank_c_o : out std_logic;
      bank_m_o : out std_logic
   );
end entity fgc;

architecture synthesis of fgc is

   signal bank_f : std_logic := '0';
   signal bank_g : std_logic := '0';
   signal bank_c : std_logic := '0';
   signal bank_m : std_logic := '0';

begin

   p_move : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case item_i is
            when "00" =>
               -- Move MAN only
               bank_m <= not bank_m;

            when "01" =>
               if bank_f = bank_m then
                  -- Move MAN and FOX
                  bank_f <= not bank_f;
                  bank_m <= not bank_m;
               end if;

            when "10" =>
               if bank_g = bank_m then
                  -- Move MAN and GOAT
                  bank_g <= not bank_g;
                  bank_m <= not bank_m;
               end if;

            when "11" =>
               if bank_c = bank_m then
                  -- Move MAN and CABBAGE
                  bank_c <= not bank_c;
                  bank_m <= not bank_m;
               end if;

            when others =>
               null;
         end case;

         if rst_i = '1' then
            -- Initially, everything is on bank 0
            bank_f <= '0';
            bank_g <= '0';
            bank_c <= '0';
            bank_m <= '0';
         end if;
      end if;
   end process p_move;

   -- Connect output signals
   bank_f_o <= bank_f;
   bank_g_o <= bank_g;
   bank_c_o <= bank_c;
   bank_m_o <= bank_m;

end architecture synthesis;

