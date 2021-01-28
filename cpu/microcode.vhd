library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- address bitmap:
-- bit  5   : read from dst
-- bit  4   : write to dst
-- bit  3   : src mem
-- bit  2   : dst mem
-- bits 1-0 : count
--
-- value bitmap
-- bit 6 : last
-- bit 5 : mem to alu src
-- bit 4 : mem to alu dst
-- bit 3 : mem read to src
-- bit 2 : mem read to dst
-- bit 1 : mem write
-- bit 0 : reg write

entity microcode is
   port (
      addr_i  : in  std_logic_vector(5 downto 0);
      value_o : out std_logic_vector(6 downto 0)
   );
end entity microcode;

architecture synthesis of microcode is

   constant C_LAST         : std_logic_vector(6 downto 0) := "1000000";
   constant C_MEM_ALU_SRC  : std_logic_vector(6 downto 0) := "0100000";
   constant C_MEM_ALU_DST  : std_logic_vector(6 downto 0) := "0010000";
   constant C_MEM_READ_SRC : std_logic_vector(6 downto 0) := "0001000";
   constant C_MEM_READ_DST : std_logic_vector(6 downto 0) := "0000100";
   constant C_MEM_WRITE    : std_logic_vector(6 downto 0) := "0000010";
   constant C_REG_WRITE    : std_logic_vector(6 downto 0) := "0000001";

   type microcode_t is array (0 to 63) of std_logic_vector(6 downto 0);
   constant C_MICROCODE : microcode_t := (
      -- NOT USED R, R
      C_LAST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- NOT USED R, @R
      C_LAST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- NOT USED @R, R
      C_LAST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- NOT USED @R, @R
      C_LAST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- MOVE R, R
      C_LAST or C_REG_WRITE,
      C_LAST,
      C_LAST,
      C_LAST,

      -- MOVE R, @R
      C_LAST or C_MEM_WRITE,
      C_LAST,
      C_LAST,
      C_LAST,

      -- MOVE @R, R
      C_MEM_READ_SRC,
      C_LAST or C_MEM_ALU_SRC or C_REG_WRITE,
      C_LAST,
      C_LAST,

      -- MOVE @R, @R
      C_MEM_READ_SRC,
      C_LAST or C_MEM_ALU_SRC or C_MEM_WRITE,
      C_LAST,
      C_LAST,

      -- CMP R, R
      C_LAST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- CMP R, @R
      C_LAST or C_MEM_READ_DST,
      C_LAST,
      C_LAST,
      C_LAST,

      -- CMP @R, R
      C_LAST or C_MEM_READ_SRC,
      C_LAST,
      C_LAST,
      C_LAST,

      -- CMP @R, @R
      C_MEM_READ_SRC,
      C_LAST or C_MEM_READ_DST,
      C_LAST,
      C_LAST,

      -- ADD R, R
      C_LAST or C_REG_WRITE,
      C_LAST,
      C_LAST,
      C_LAST,

      -- ADD R, @R
      C_MEM_READ_DST,
      C_LAST or C_MEM_ALU_DST or C_MEM_WRITE,
      C_LAST,
      C_LAST,

      -- ADD @R, R
      C_MEM_READ_SRC,
      C_LAST or C_MEM_ALU_SRC or C_REG_WRITE,
      C_LAST,
      C_LAST,

      -- ADD @R, @R
      C_MEM_READ_SRC,
      C_MEM_ALU_SRC or C_MEM_READ_DST,
      C_LAST or C_MEM_ALU_DST or C_MEM_WRITE,
      C_LAST
   ); --  constant C_MICROCODE : microcode_t := (

begin

   value_o <= C_MICROCODE(to_integer(addr_i));

end architecture synthesis;

