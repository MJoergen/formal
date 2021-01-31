library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.cpu_constants.all;

entity registers is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      src_reg_i     : in  std_logic_vector(3 downto 0);
      src_val_o     : out std_logic_vector(15 downto 0);
      dst_reg_i     : in  std_logic_vector(3 downto 0);
      dst_val_o     : out std_logic_vector(15 downto 0);
      flags_o       : out std_logic_vector(15 downto 0);
      flags_we_i    : in  std_logic;
      flags_i       : in  std_logic_vector(15 downto 0);
      reg_we_i      : in  std_logic;
      reg_addr_i    : in  std_logic_vector(3 downto 0);
      reg_val_i     : in  std_logic_vector(15 downto 0)
   );
end entity registers;

architecture synthesis of registers is

   type upper_mem_t is array (8 to 15) of std_logic_vector(15 downto 0);
   type lower_mem_t is array (0 to 8*256-1) of std_logic_vector(15 downto 0);

   signal upper_regs : upper_mem_t := (others => (others => '0'));
   signal lower_regs : lower_mem_t := (others => (others => '0'));

   signal pc : std_logic_vector(15 downto 0);
   signal sr : std_logic_vector(15 downto 0);
   signal sp : std_logic_vector(15 downto 0);

begin

   flags_o <= sr;

   src_val_o <= pc when to_integer(src_reg_i) = C_REG_PC else
                sr when to_integer(src_reg_i) = C_REG_SR else
                sp when to_integer(src_reg_i) = C_REG_SP else
                upper_regs(to_integer(src_reg_i)) when to_integer(src_reg_i) >= 8 else
                lower_regs(to_integer(sr(15 downto 8))*8+to_integer(src_reg_i));

   dst_val_o <= pc when to_integer(dst_reg_i) = C_REG_PC else
                sr when to_integer(dst_reg_i) = C_REG_SR else
                sp when to_integer(dst_reg_i) = C_REG_SP else
                upper_regs(to_integer(dst_reg_i)) when to_integer(dst_reg_i) >= 8 else
                lower_regs(to_integer(sr(15 downto 8))*8+to_integer(dst_reg_i));

   p_special : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if reg_we_i = '1' and to_integer(reg_addr_i) = C_REG_PC then
            pc <= reg_val_i;
         end if;

         if reg_we_i = '1' and to_integer(reg_addr_i) = C_REG_SP then
            sp <= reg_val_i;
         end if;

         if flags_we_i = '1' then
            sr <= flags_i;
         end if;

         if reg_we_i = '1' and to_integer(reg_addr_i) = C_REG_SR then
            sr <= reg_val_i or X"0001";
         end if;

         if rst_i = '1' then
            pc <= X"0000";
            sr <= X"0001";
            sp <= X"0000";
         end if;
      end if;
   end process p_special;

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if reg_we_i = '1' then
            if to_integer(reg_addr_i) >= 8 then
               upper_regs(to_integer(reg_addr_i)) <= reg_val_i;
            else
               lower_regs(to_integer(sr(15 downto 8))*8+to_integer(reg_addr_i)) <= reg_val_i;
            end if;
         end if;

-- pragma synthesis_off
         if rst_i = '1' then
            for i in 0 to 7 loop
               lower_regs(i) <= X"111" * to_std_logic_vector(i, 4);
            end loop;
            for i in 8 to 15 loop
               upper_regs(i) <= X"111" * to_std_logic_vector(i, 4);
            end loop;
         end if;
-- pragma synthesis_on
      end if;
   end process p_write;

end architecture synthesis;

