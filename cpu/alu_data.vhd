library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity alu_data is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      opcode_i   : in  std_logic_vector(3 downto 0);
      src_data_i : in  std_logic_vector(15 downto 0);
      dst_data_i : in  std_logic_vector(15 downto 0);
      sr_i       : in  std_logic_vector(15 downto 0);
      res_data_o : out std_logic_vector(16 downto 0)
   );
end entity alu_data;

architecture synthesis of alu_data is

   signal res_data : std_logic_vector(16 downto 0);
   signal res_shr  : std_logic_vector(16 downto 0);
   signal res_shl  : std_logic_vector(16 downto 0);

begin

   -- dst << src, fill with X, shift to C
   p_shift_left : process (src_data_i, dst_data_i, sr_i)
      variable tmp   : std_logic_vector(32 downto 0);
      variable res   : std_logic_vector(16 downto 0);
      variable shift : integer;
   begin
      -- Prepare for shift
      tmp(32)           := sr_i(C_SR_C);  -- Old value of C
      tmp(31 downto 16) := dst_data_i;
      tmp(15 downto 0)  := (15 downto 0 => sr_i(C_SR_X));  -- Fill with X

      shift := to_integer(unsigned(src_data_i));
      if shift <= 16 then
         res := tmp(32-shift downto 16-shift);
      else
         res := (others => sr_i(C_SR_X));
      end if;

      res_shl <= res;
   end process p_shift_left;


   -- dst >> src, fill with C, shift to X
   p_shift_right : process (src_data_i, dst_data_i, sr_i)
      variable tmp   : std_logic_vector(32 downto 0);
      variable res   : std_logic_vector(16 downto 0);
      variable shift : integer;
   begin
      -- Prepare for shift
      tmp(32 downto 17) := (32 downto 17 => sr_i(C_SR_C));  -- Fill with C
      tmp(16 downto 1)  := dst_data_i;
      tmp(0)            := sr_i(C_SR_X);  -- Old value of X

      shift := to_integer(unsigned(src_data_i));
      if shift <= 16 then
         res := tmp(shift+16 downto shift);
      else
         res := (others => sr_i(C_SR_C));
      end if;

      res_shr <= res;
   end process p_shift_right;


   p_res_data : process (src_data_i, dst_data_i, opcode_i, sr_i, res_shl, res_shr)
   begin
      res_data <= ("0" & src_data_i);  -- Default value to avoid latches
      case to_integer(unsigned(opcode_i)) is
         when C_OPCODE_MOVE => res_data <= "0" & src_data_i;
         when C_OPCODE_ADD  => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) + ("0" & unsigned(src_data_i)));
         when C_OPCODE_ADDC => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) + ("0" & unsigned(src_data_i)) + (X"0000" & sr_i(C_SR_C)));
         when C_OPCODE_SUB  => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) - ("0" & unsigned(src_data_i)));
         when C_OPCODE_SUBC => res_data <= std_logic_vector(("0" & unsigned(dst_data_i)) - ("0" & unsigned(src_data_i)) - (X"0000" & sr_i(C_SR_C)));
         when C_OPCODE_SHL  => res_data <= res_shl(16) & (res_shl(15 downto 0));
         when C_OPCODE_SHR  => res_data <= res_shr(0) & (res_shr(16 downto 1));
         when C_OPCODE_SWAP => res_data <= "0" & (src_data_i(7 downto 0) & src_data_i(15 downto 8));
         when C_OPCODE_NOT  => res_data <= "0" & (not src_data_i);
         when C_OPCODE_AND  => res_data <= "0" & (dst_data_i and src_data_i);
         when C_OPCODE_OR   => res_data <= "0" & (dst_data_i or src_data_i);
         when C_OPCODE_XOR  => res_data <= "0" & (dst_data_i xor src_data_i);
         when C_OPCODE_CMP  => null; -- TBD
         when C_OPCODE_RES  => null; -- TBD
         when C_OPCODE_CTRL => null; -- TBD
         when C_OPCODE_JMP  => null; -- TBD
         when others    => null;
      end case;
   end process p_res_data;

   res_data_o <= res_data;

end architecture synthesis;

