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

   constant C_CMD_FP : std_logic_vector(3 downto 0) := "0101";
   constant C_CMD_F2 : std_logic_vector(3 downto 0) := "0110";
   constant C_CMD_FM : std_logic_vector(3 downto 0) := "0111";

   constant C_CMD_RP : std_logic_vector(3 downto 0) := "1001";
   constant C_CMD_R2 : std_logic_vector(3 downto 0) := "1010";
   constant C_CMD_RM : std_logic_vector(3 downto 0) := "1011";

   constant C_CMD_UP : std_logic_vector(3 downto 0) := "1101";
   constant C_CMD_U2 : std_logic_vector(3 downto 0) := "1110";
   constant C_CMD_UM : std_logic_vector(3 downto 0) := "1111";

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
      assert done = '1';

      -- Test period of each rotation
      repeat(C_CMD_FP, 4); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_F2, 2); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_FM, 4); assert done = '1';
      repeat("0000", 2);

      repeat(C_CMD_RP, 4); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_R2, 2); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_RM, 4); assert done = '1';
      repeat("0000", 2);

      repeat(C_CMD_UP, 4); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_U2, 2); assert done = '1';
      repeat("0000", 1);
      repeat(C_CMD_UM, 4); assert done = '1';
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

