library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This attempts to solve the 2x2x2 Rubik's cube using formal methods.
--
-- The cube is described by the position and orientation of the 
-- eight corners.
-- The six faces are named Left, Front, Right, Back, Up, and Down.
-- The eight corners are hence named UBL, UBR, UFL, UFR, DBL, DBR,
-- DFL, and DFR.
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
-- The output signal done_o is true when the cube is solved.

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

   -- The initial condition is generated from the simulation testbench
   -- Bits 5-3 denote the identity of the corner piece, whereas
   -- bits 2-0 denote the orientation.
   signal corner_ubl : std_logic_vector(5 downto 0) := "110100";
   signal corner_ubr : std_logic_vector(5 downto 0) := "000010";
   signal corner_ufl : std_logic_vector(5 downto 0) := "001001";
   signal corner_ufr : std_logic_vector(5 downto 0) := "011010";
   signal corner_dbl : std_logic_vector(5 downto 0) := "100001";
   signal corner_dbr : std_logic_vector(5 downto 0) := "101010";
   signal corner_dfl : std_logic_vector(5 downto 0) := "010001";
   signal corner_dfr : std_logic_vector(5 downto 0) := "111010";

--   -- Swapped corners
--   signal corner_ubl : std_logic_vector(5 downto 0) := "000001";
--   signal corner_ubr : std_logic_vector(5 downto 0) := "001001";
--   signal corner_ufl : std_logic_vector(5 downto 0) := "011001";   -- swapped
--   signal corner_ufr : std_logic_vector(5 downto 0) := "010001";   -- swapped
--   signal corner_dbl : std_logic_vector(5 downto 0) := "100001";
--   signal corner_dbr : std_logic_vector(5 downto 0) := "101001";
--   signal corner_dfl : std_logic_vector(5 downto 0) := "110001";
--   signal corner_dfr : std_logic_vector(5 downto 0) := "111001";

--   -- Twisted corners
--   signal corner_ubl : std_logic_vector(5 downto 0) := "000001";
--   signal corner_ubr : std_logic_vector(5 downto 0) := "001001";
--   signal corner_ufl : std_logic_vector(5 downto 0) := "010010";  -- twisted
--   signal corner_ufr : std_logic_vector(5 downto 0) := "011100";  -- twisted
--   signal corner_dbl : std_logic_vector(5 downto 0) := "100001";
--   signal corner_dbr : std_logic_vector(5 downto 0) := "101001";
--   signal corner_dfl : std_logic_vector(5 downto 0) := "110001";
--   signal corner_dfr : std_logic_vector(5 downto 0) := "111001";

begin

   process (clk_i)

      -- Rotate a corner piece counter clockwise
      function left(arg : std_logic_vector) return std_logic_vector is
      begin
         return arg(5 downto 3) & arg(0) & arg(2) & arg(1);
      end function left;

      -- Rotate a corner piece clockwise
      function right(arg : std_logic_vector) return std_logic_vector is
      begin
         return arg(5 downto 3) & arg(1) & arg(0) & arg(2);
      end function right;

   begin
      if rising_edge(clk_i) then
         case cmd_i is

            when C_CMD_FP => -- : F+
               corner_ufr <= right(corner_ufl);
               corner_ufl <= left(corner_dfl);
               corner_dfl <= right(corner_dfr);
               corner_dfr <= left(corner_ufr);

            when C_CMD_F2 => -- : F2
               corner_ufl <= corner_dfr;
               corner_dfr <= corner_ufl;
               corner_ufr <= corner_dfl;
               corner_dfl <= corner_ufr;

            when C_CMD_FM => -- : F-
               corner_ufl <= left(corner_ufr);
               corner_ufr <= right(corner_dfr);
               corner_dfr <= left(corner_dfl);
               corner_dfl <= right(corner_ufl);

            when C_CMD_RP => -- : R+
               corner_ubr <= right(corner_ufr);
               corner_ufr <= left(corner_dfr);
               corner_dfr <= right(corner_dbr);
               corner_dbr <= left(corner_ubr);

            when C_CMD_R2 => -- : R2
               corner_ufr <= corner_dbr;
               corner_dbr <= corner_ufr;
               corner_ubr <= corner_dfr;
               corner_dfr <= corner_ubr;

            when C_CMD_RM => -- : R-
               corner_ufr <= left(corner_ubr);
               corner_ubr <= right(corner_dbr);
               corner_dbr <= left(corner_dfr);
               corner_dfr <= right(corner_ufr);

            when C_CMD_UP => -- : U+
               corner_ubr <= corner_ubl;
               corner_ubl <= corner_ufl;
               corner_ufl <= corner_ufr;
               corner_ufr <= corner_ubr;

            when C_CMD_U2 => -- : U2
               corner_ubl <= corner_ufr;
               corner_ufr <= corner_ubl;
               corner_ubr <= corner_ufl;
               corner_ufl <= corner_ubr;

            when C_CMD_UM => -- : U-
               corner_ubl <= corner_ubr;
               corner_ubr <= corner_ufr;
               corner_ufr <= corner_ufl;
               corner_ufl <= corner_ubl;

            when others => null; -- Ignore any illegal commands
         end case;

         -- Reset the cube to the solved position.
         if rst_i = '1' then
            corner_ubl <= "000001";
            corner_ubr <= "001001";
            corner_ufl <= "010001";
            corner_ufr <= "011001";
            corner_dbl <= "100001";
            corner_dbr <= "101001";
            corner_dfl <= "110001";
            corner_dfr <= "111001";
         end if;
      end if;
   end process;

   -- Check whether the cube is in the solved position.
   done_o <= '1' when
            corner_ubl = "000001" and
            corner_ubr = "001001" and
            corner_ufl = "010001" and
            corner_ufr = "011001" and
            corner_dbl = "100001" and
            corner_dbr = "101001" and
            corner_dfl = "110001" and
            corner_dfr = "111001" else '0';

end architecture synthesis;

