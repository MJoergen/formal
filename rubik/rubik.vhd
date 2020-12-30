library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This attempts to solve the 2x2x2 Rubik's cube using formal methods.
--
-- The cube is described by the following 24 signals
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
-- Each place has one of six colours.
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
   generic (
      G_FORMAL : boolean := false
   );
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      cmd_i  : in  std_logic_vector(3 downto 0);
      done_o : out std_logic
   );
end entity rubik;

architecture synthesis of rubik is

   signal u0 : std_logic_vector(2 downto 0) := "000";
   signal u1 : std_logic_vector(2 downto 0) := "000";
   signal u2 : std_logic_vector(2 downto 0) := "000";
   signal u3 : std_logic_vector(2 downto 0) := "000";

   signal f0 : std_logic_vector(2 downto 0) := "001";
   signal f1 : std_logic_vector(2 downto 0) := "001";
   signal f2 : std_logic_vector(2 downto 0) := "001";
   signal f3 : std_logic_vector(2 downto 0) := "001";

   signal r0 : std_logic_vector(2 downto 0) := "010";
   signal r1 : std_logic_vector(2 downto 0) := "010";
   signal r2 : std_logic_vector(2 downto 0) := "010";
   signal r3 : std_logic_vector(2 downto 0) := "010";

   signal d0 : std_logic_vector(2 downto 0) := "011";
   signal d1 : std_logic_vector(2 downto 0) := "011";
   signal d2 : std_logic_vector(2 downto 0) := "011";
   signal d3 : std_logic_vector(2 downto 0) := "011";

   signal b0 : std_logic_vector(2 downto 0) := "100";
   signal b1 : std_logic_vector(2 downto 0) := "100";
   signal b2 : std_logic_vector(2 downto 0) := "100";
   signal b3 : std_logic_vector(2 downto 0) := "100";

   signal l0 : std_logic_vector(2 downto 0) := "101";
   signal l1 : std_logic_vector(2 downto 0) := "101";
   signal l2 : std_logic_vector(2 downto 0) := "101";
   signal l3 : std_logic_vector(2 downto 0) := "101";

   constant C_CMD_FP : std_logic_vector(3 downto 0) := "0101";
   constant C_CMD_F2 : std_logic_vector(3 downto 0) := "0110";
   constant C_CMD_FM : std_logic_vector(3 downto 0) := "0111";

   constant C_CMD_RP : std_logic_vector(3 downto 0) := "1001";
   constant C_CMD_R2 : std_logic_vector(3 downto 0) := "1010";
   constant C_CMD_RM : std_logic_vector(3 downto 0) := "1011";

   constant C_CMD_UP : std_logic_vector(3 downto 0) := "1101";
   constant C_CMD_U2 : std_logic_vector(3 downto 0) := "1110";
   constant C_CMD_UM : std_logic_vector(3 downto 0) := "1111";

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

            when others => null;
         end case;

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

   done_o <= '1' when
             u0 = "000" and u1 = "000" and u2 = "000" and u3 = "000" and
             f0 = "001" and f1 = "001" and f2 = "001" and f3 = "001" and
             r0 = "010" and r1 = "010" and r2 = "010" and r3 = "010" and
             d0 = "011" and d1 = "011" and d2 = "011" and d3 = "011" and
             b0 = "100" and b1 = "100" and b2 = "100" and b3 = "100" and
             l0 = "101" and l1 = "101" and l2 = "101" and l3 = "101" else '0';


   ------------------------
   -- Formal verification
   ------------------------

   formal_gen : if G_FORMAL generate

      signal f_rst        : std_logic := '1';
      signal f_num_colors : integer_vector(0 to 7);
      signal f_output     : std_logic_vector(71 downto 0);

      constant C_PATTERN : std_logic_vector(71 downto 0) :=
         B"101_100_000_001" &
         B"100_010_101_011" &
         B"000_101_001_011" &
         B"000_010_011_100" &
         B"000_011_010_100" &
         B"001_010_101_001";

   begin

      -- set all declarations to run on clk_i
      -- psl default clock is rising_edge(clk_i);


      -----------------------------
      -- ASSUMPTIONS ABOUT INPUTS
      -----------------------------

      process (clk_i)
      begin
         if rising_edge(clk_i) then
            f_rst <= '0';
         end if;
      end process;

      -- Require reset at startup.
      -- This is to ensure BMC starts in a valid state.
      -- psl f_reset : assume always {rst_i or not f_rst};


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- psl f_edge_u2_f0 : assert always {u2 /= f0} abort rst_i;
      -- psl f_edge_u3_f1 : assert always {u3 /= f1} abort rst_i;
      -- psl f_edge_l1_f0 : assert always {l1 /= f0} abort rst_i;
      -- psl f_edge_l3_f2 : assert always {l3 /= f2} abort rst_i;
      -- psl f_edge_d0_f2 : assert always {d0 /= f2} abort rst_i;
      -- psl f_edge_d1_f3 : assert always {d1 /= f3} abort rst_i;
      -- psl f_edge_r2_f3 : assert always {r2 /= f3} abort rst_i;
      -- psl f_edge_r0_f1 : assert always {r0 /= f1} abort rst_i;
      -- psl f_edge_u2_l1 : assert always {u2 /= l1} abort rst_i;
      -- psl f_edge_u0_l0 : assert always {u0 /= l0} abort rst_i;
      -- psl f_edge_l3_d0 : assert always {l3 /= d0} abort rst_i;
      -- psl f_edge_l2_d2 : assert always {l2 /= d2} abort rst_i;
      -- psl f_edge_d1_r2 : assert always {d1 /= r2} abort rst_i;
      -- psl f_edge_d3_r3 : assert always {d3 /= r3} abort rst_i;
      -- psl f_edge_r0_u3 : assert always {r0 /= u3} abort rst_i;
      -- psl f_edge_r1_u1 : assert always {r1 /= u1} abort rst_i;
      -- psl f_edge_r1_b0 : assert always {r1 /= b0} abort rst_i;
      -- psl f_edge_r3_b2 : assert always {r3 /= b2} abort rst_i;
      -- psl f_edge_d3_b2 : assert always {d3 /= b2} abort rst_i;
      -- psl f_edge_d2_b3 : assert always {d2 /= b3} abort rst_i;
      -- psl f_edge_u0_b1 : assert always {u0 /= b1} abort rst_i;
      -- psl f_edge_u1_b0 : assert always {u1 /= b0} abort rst_i;
      -- psl f_edge_b1_l0 : assert always {b1 /= l0} abort rst_i;
      -- psl f_edge_b3_l2 : assert always {b3 /= l2} abort rst_i;

      process (all)
         variable num_colors : integer_vector(0 to 7);
      begin
         num_colors := (others => 0);
         num_colors(conv_integer(u0)) := num_colors(conv_integer(u0)) + 1;
         num_colors(conv_integer(u1)) := num_colors(conv_integer(u1)) + 1;
         num_colors(conv_integer(u2)) := num_colors(conv_integer(u2)) + 1;
         num_colors(conv_integer(u3)) := num_colors(conv_integer(u3)) + 1;
         num_colors(conv_integer(f0)) := num_colors(conv_integer(f0)) + 1;
         num_colors(conv_integer(f1)) := num_colors(conv_integer(f1)) + 1;
         num_colors(conv_integer(f2)) := num_colors(conv_integer(f2)) + 1;
         num_colors(conv_integer(f3)) := num_colors(conv_integer(f3)) + 1;
         num_colors(conv_integer(r0)) := num_colors(conv_integer(r0)) + 1;
         num_colors(conv_integer(r1)) := num_colors(conv_integer(r1)) + 1;
         num_colors(conv_integer(r2)) := num_colors(conv_integer(r2)) + 1;
         num_colors(conv_integer(r3)) := num_colors(conv_integer(r3)) + 1;
         num_colors(conv_integer(d0)) := num_colors(conv_integer(d0)) + 1;
         num_colors(conv_integer(d1)) := num_colors(conv_integer(d1)) + 1;
         num_colors(conv_integer(d2)) := num_colors(conv_integer(d2)) + 1;
         num_colors(conv_integer(d3)) := num_colors(conv_integer(d3)) + 1;
         num_colors(conv_integer(b0)) := num_colors(conv_integer(b0)) + 1;
         num_colors(conv_integer(b1)) := num_colors(conv_integer(b1)) + 1;
         num_colors(conv_integer(b2)) := num_colors(conv_integer(b2)) + 1;
         num_colors(conv_integer(b3)) := num_colors(conv_integer(b3)) + 1;
         num_colors(conv_integer(l0)) := num_colors(conv_integer(l0)) + 1;
         num_colors(conv_integer(l1)) := num_colors(conv_integer(l1)) + 1;
         num_colors(conv_integer(l2)) := num_colors(conv_integer(l2)) + 1;
         num_colors(conv_integer(l3)) := num_colors(conv_integer(l3)) + 1;
         f_num_colors <= num_colors;
      end process;

      -- psl f_colors : assert always {f_num_colors = (0 to 5 => 4, 6 to 7 => 0)} abort rst_i;


      --------------------------------------------
      -- COVER STATEMENTS TO VERIFY REACHABILITY
      --------------------------------------------

      -- psl f_done : cover {not done_o and not rst_i; done_o};

      f_output <= u0 & u1 & u2 & u3 &
                f0 & f1 & f2 & f3 &
                r0 & r1 & r2 & r3 &
                d0 & d1 & d2 & d3 &
                b0 & b1 & b2 & b3 &
                l0 & l1 & l2 & l3;

      -- psl f_pattern : cover {f_output = C_PATTERN};

   end generate formal_gen;

end architecture synthesis;

