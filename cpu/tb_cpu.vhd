library ieee;
use ieee.std_logic_1164.all;

entity tb_cpu is
end entity tb_cpu;

architecture simulation of tb_cpu is

   signal clk  : std_logic;
   signal rstn : std_logic;

begin

   p_clk : process
   begin
      clk <= '1', '0' after 5 ns;
      wait for 10 ns; -- 100 MHz
   end process p_clk;

   p_rstn : process
   begin
      rstn <= '0';
      wait for 100 ns;
      wait until clk = '1';
      rstn <= '1';
      wait;
   end process p_rstn;

   i_system : entity work.system
      port map (
         clk_i  => clk,
         rstn_i => rstn
      ); -- i_cpu

end architecture simulation;

