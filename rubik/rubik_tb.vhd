library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rubik_tb is
end entity rubik_tb;


architecture synthesis of rubik_tb is

   signal clk  : std_logic;
   signal rst  : std_logic;
   signal cmd  : std_logic_vector(3 downto 0);
   signal done : std_logic;

begin

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      rst <= '0';
      wait until clk = '1';
      wait;
   end process p_rst;

   p_test : process
   begin
      cmd <= "0000";
      wait until rst = '0';
      wait until clk = '1';

      cmd <= "0101";
      wait until clk = '1';
      cmd <= "0000";
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      cmd <= "0101";
      wait until clk = '1';
      cmd <= "0000";
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      cmd <= "0101";
      wait until clk = '1';
      cmd <= "0000";
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      cmd <= "0101";
      wait until clk = '1';
      cmd <= "0000";
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      wait;
   end process p_test;

   i_rubik : entity work.rubik
      port map (
         clk_i  => clk,
         rst_i  => rst,
         cmd_i  => cmd,
         done_o => done
      ); -- i_rubik

end architecture synthesis;

