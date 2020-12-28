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

   -- Random number generator
   signal prbs255 : std_logic_vector(254 downto 0) := (others => '1');

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

   --------------------------------------------
   -- Random number generator, based on a PRBS
   --------------------------------------------

   p_prbs255 : process (clk)
   begin
      if rising_edge(clk) then
         prbs255 <= prbs255(253 downto 0)
            & (prbs255(254) xor prbs255(13) xor prbs255(17) xor prbs255(126));
      end if;
   end process p_prbs255;


   p_test : process
      procedure repeat(cmd_p : std_logic_vector(3 downto 0); count_p : integer) is
      begin
         for i in 1 to count_p loop
            cmd <= cmd_p;
            wait until clk = '1';
            cmd <= "0000";
            wait until clk = '1';
            wait until clk = '1';
            wait until clk = '1';
         end loop;
      end procedure repeat;

   begin
      cmd <= "0000";
      wait until rst = '0';
      wait until clk = '1';

      repeat("0101", 4);
      repeat("0000", 1);
      repeat("0110", 2);
      repeat("0000", 1);
      repeat("0111", 4);
      repeat("0000", 2);

      repeat("1001", 4);
      repeat("0000", 1);
      repeat("1010", 2);
      repeat("0000", 1);
      repeat("1011", 4);
      repeat("0000", 2);

      repeat("1101", 4);
      repeat("0000", 1);
      repeat("1110", 2);
      repeat("0000", 1);
      repeat("1111", 4);
      repeat("0000", 2);

      -- Generate smoe random turnings
      for i in 1 to 50 loop
         repeat(prbs255(3 downto 0), 1);
      end loop;

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

