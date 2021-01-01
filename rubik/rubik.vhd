library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This attempts to solve the 2x2x2 Rubik's cube using formal methods.
--
-- The cube is described by the following 24 tiles
--
--         U0 U1
--         U2 U3
--         -----
-- L0 L1 | F0 F1 | R0 R1 | B0 B1
-- L2 L3 | F2 F3 | R2 R3 | B2 B3
--         -----
--         D0 D1
--         D2 D3
--
-- The six faces are named Left, Front, Right, Back, Up, and Down.
--
-- Each tile has one of six colours.
--
-- The input signal cmd_i is interpreted as follows
-- 0101 : F+
-- 0110 : F2
-- 0111 : F-
-- 1001 : R+
-- 1010 : R2
-- 1011 : R-
-- 1101 : U+
-- 1110 : U2
-- 1111 : U-
-- Only these combinations of input pins are allowed
--
-- The output signal done_o is true when
-- Ux = 0
-- Fx = 1
-- Rx = 2
-- Dx = 3
-- Bx = 4
-- Lx = 5

entity rubik is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      cmd_i  : in  std_logic_vector(3 downto 0);
      done_o : out std_logic
   );
end entity rubik;

architecture synthesis of rubik is

   -- Valid input commands
   constant C_CMD_FP : std_logic_vector(3 downto 0) := "0101"; -- F+
   constant C_CMD_F2 : std_logic_vector(3 downto 0) := "0110"; -- F2
   constant C_CMD_FM : std_logic_vector(3 downto 0) := "0111"; -- F-

   constant C_CMD_RP : std_logic_vector(3 downto 0) := "1001"; -- R+
   constant C_CMD_R2 : std_logic_vector(3 downto 0) := "1010"; -- R2
   constant C_CMD_RM : std_logic_vector(3 downto 0) := "1011"; -- R-

   constant C_CMD_UP : std_logic_vector(3 downto 0) := "1101"; -- U+
   constant C_CMD_U2 : std_logic_vector(3 downto 0) := "1110"; -- U2
   constant C_CMD_UM : std_logic_vector(3 downto 0) := "1111"; -- U-

   -- The initial condition is chosen from the output of the testbench rubik_tb.vhd.
   signal u0 : std_logic_vector(2 downto 0) := "101";
   signal u1 : std_logic_vector(2 downto 0) := "100";
   signal u2 : std_logic_vector(2 downto 0) := "000";
   signal u3 : std_logic_vector(2 downto 0) := "001";

   signal f0 : std_logic_vector(2 downto 0) := "100";
   signal f1 : std_logic_vector(2 downto 0) := "010";
   signal f2 : std_logic_vector(2 downto 0) := "101";
   signal f3 : std_logic_vector(2 downto 0) := "011";

   signal r0 : std_logic_vector(2 downto 0) := "000";
   signal r1 : std_logic_vector(2 downto 0) := "101";
   signal r2 : std_logic_vector(2 downto 0) := "001";
   signal r3 : std_logic_vector(2 downto 0) := "011";

   signal d0 : std_logic_vector(2 downto 0) := "000";
   signal d1 : std_logic_vector(2 downto 0) := "010";
   signal d2 : std_logic_vector(2 downto 0) := "011";
   signal d3 : std_logic_vector(2 downto 0) := "100";

   signal b0 : std_logic_vector(2 downto 0) := "000";
   signal b1 : std_logic_vector(2 downto 0) := "011";
   signal b2 : std_logic_vector(2 downto 0) := "010";
   signal b3 : std_logic_vector(2 downto 0) := "100";

   signal l0 : std_logic_vector(2 downto 0) := "001";
   signal l1 : std_logic_vector(2 downto 0) := "010";
   signal l2 : std_logic_vector(2 downto 0) := "101";
   signal l3 : std_logic_vector(2 downto 0) := "001";

begin

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         case cmd_i is

--         U0 U1
--         U2 U3
--         -----
-- L0 L1 | F0 F1 | R0 R1 | B0 B1
-- L2 L3 | F2 F3 | R2 R3 | B2 B3
--         -----
--         D0 D1
--         D2 D3

            when C_CMD_FP => -- : F+
               f1 <= f0;
               f3 <= f1;
               f2 <= f3;
               f0 <= f2;
               --
               d1 <= r0;
               l3 <= d1;
               u2 <= l3;
               r0 <= u2;
               d0 <= r2;
               l1 <= d0;
               u3 <= l1;
               r2 <= u3;

            when C_CMD_F2 => -- : F2
               f3 <= f0;
               f0 <= f3;
               f2 <= f1;
               f1 <= f2;
               --
               l3 <= r0;
               r0 <= l3;
               u2 <= d1;
               d1 <= u2;
               l1 <= r2;
               r2 <= l1;
               d0 <= u3;
               u3 <= d0;

            when C_CMD_FM => -- : F-
               f2 <= f0;
               f3 <= f2;
               f1 <= f3;
               f0 <= f1;
               --
               r0 <= d1;
               d1 <= l3;
               l3 <= u2;
               u2 <= r0;

               r2 <= d0;
               d0 <= l1;
               l1 <= u3;
               u3 <= r2;


--         U2 U0
--         U3 U1
--         -----
-- F0 F1 | R0 R1 | B0 B1 | L0 L1
-- F2 F3 | R2 R3 | B2 B3 | L2 L3
--         -----
--         D1 D3
--         D0 D2

            when C_CMD_RP => -- : R+
               r1 <= r0;
               r3 <= r1;
               r2 <= r3;
               r0 <= r2;
               --
               d3 <= b0;
               f3 <= d3;
               u3 <= f3;
               b0 <= u3;
               d1 <= b2;
               f1 <= d1;
               u1 <= f1;
               b2 <= u1;

            when C_CMD_R2 => -- : R2
               r0 <= r3;
               r3 <= r0;
               r1 <= r2;
               r2 <= r1;
               --
               f3 <= b0;
               b0 <= f3;
               u3 <= d3;
               d3 <= u3;
               b2 <= f1;
               f1 <= b2;
               d1 <= u1;
               u1 <= d1;

            when C_CMD_RM => -- : R-
               r2 <= r0;
               r3 <= r2;
               r1 <= r3;
               r0 <= r1;
               --
               b0 <= d3;
               d3 <= f3;
               f3 <= u3;
               u3 <= b0;
               b2 <= d1;
               d1 <= f1;
               f1 <= u1;
               u1 <= b2;


--         B3 B2
--         B1 B0
--         -----
-- L2 L0 | U0 U1 | R1 R3 | D3 D2
-- L3 L1 | U2 U3 | R0 R2 | D1 D0
--         -----
--         F0 F1
--         F2 F3

            when C_CMD_UP => -- : U+
               u1 <= u0;
               u3 <= u1;
               u2 <= u3;
               u0 <= u2;
               --
               f1 <= r1;
               l1 <= f1;
               b1 <= l1;
               r1 <= b1;
               f0 <= r0;
               l0 <= f0;
               b0 <= l0;
               r0 <= b0;

            when C_CMD_U2 => -- : U2
               u3 <= u0;
               u0 <= u3;
               u2 <= u1;
               u1 <= u2;
               --
               l1 <= r1;
               r1 <= l1;
               f1 <= b1;
               b1 <= f1;
               r0 <= l0;
               l0 <= r0;
               f0 <= b0;
               b0 <= f0;

            when C_CMD_UM => -- : U-
               u0 <= u1;
               u2 <= u0;
               u3 <= u2;
               u1 <= u3;
               --
               r1 <= f1;
               f1 <= l1;
               l1 <= b1;
               b1 <= r1;
               r0 <= f0;
               f0 <= l0;
               l0 <= b0;
               b0 <= r0;

            when others => null; -- Ignore any illegal commands
         end case;

         -- Reset the cube to the solved position.
         if rst_i = '1' then
            u0 <= "000";
            u1 <= "000";
            u2 <= "000";
            u3 <= "000";

            f0 <= "001";
            f1 <= "001";
            f2 <= "001";
            f3 <= "001";

            r0 <= "010";
            r1 <= "010";
            r2 <= "010";
            r3 <= "010";

            d0 <= "011";
            d1 <= "011";
            d2 <= "011";
            d3 <= "011";

            b0 <= "100";
            b1 <= "100";
            b2 <= "100";
            b3 <= "100";

            l0 <= "101";
            l1 <= "101";
            l2 <= "101";
            l3 <= "101";
         end if;
      end if;
   end process;

   -- Check whether the cube is in the solved position.
   done_o <= '1' when
             u0 = "000" and u1 = "000" and u2 = "000" and u3 = "000" and
             f0 = "001" and f1 = "001" and f2 = "001" and f3 = "001" and
             r0 = "010" and r1 = "010" and r2 = "010" and r3 = "010" and
             d0 = "011" and d1 = "011" and d2 = "011" and d3 = "011" and
             b0 = "100" and b1 = "100" and b2 = "100" and b3 = "100" and
             l0 = "101" and l1 = "101" and l2 = "101" and l3 = "101" else '0';

end architecture synthesis;

