library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- Read src and dst register values and pass on to next stage
-- Split out microops:
-- * MEM_READ_SRC : Read source operand from memory
-- * MEM_READ_DST : Read destination operand from memory
-- * MEM_WRITE : Write result to memory
-- * REG_WRITE : Write result to register
-- Other information passed on is:
-- * OPCODE
-- * Source register value
-- * Destination register value

-- Nearly all instructions update the status register (R14).

use work.cpu_constants.all;

entity execute is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From decode
      dec_valid_i     : in  std_logic;
      dec_ready_o     : out std_logic;
      dec_microop_i   : in  std_logic_vector(5 downto 0);
      dec_opcode_i    : in  std_logic_vector(3 downto 0);
      dec_r14_i       : in  std_logic_vector(15 downto 0);
      dec_r14_we_i    : in  std_logic;
      dec_src_addr_i  : in  std_logic_vector(3 downto 0);
      dec_src_val_i   : in  std_logic_vector(15 downto 0);
      dec_dst_addr_i  : in  std_logic_vector(3 downto 0);
      dec_dst_val_i   : in  std_logic_vector(15 downto 0);
      dec_reg_addr_i  : in  std_logic_vector(3 downto 0);

      -- Memory
      mem_valid_o     : out std_logic;
      mem_ready_i     : in  std_logic;
      mem_op_o        : out std_logic_vector(2 downto 0);
      mem_addr_o      : out std_logic_vector(15 downto 0);
      mem_wr_data_o   : out std_logic_vector(15 downto 0);
      mem_src_valid_i : in  std_logic;
      mem_src_ready_o : out std_logic;
      mem_src_data_i  : in  std_logic_vector(15 downto 0);
      mem_dst_valid_i : in  std_logic;
      mem_dst_ready_o : out std_logic;
      mem_dst_data_i  : in  std_logic_vector(15 downto 0);

      -- Register file
      reg_r14_we_o    : out std_logic;
      reg_r14_o       : out std_logic_vector(15 downto 0);
      reg_we_o        : out std_logic;
      reg_addr_o      : out std_logic_vector(3 downto 0);
      reg_val_o       : out std_logic_vector(15 downto 0)
   );
end entity execute;

architecture synthesis of execute is

   constant C_MEM_ALU_SRC  : integer := 5;
   constant C_MEM_ALU_DST  : integer := 4;
   constant C_MEM_READ_SRC : integer := 3;
   constant C_MEM_READ_DST : integer := 2;
   constant C_MEM_WRITE    : integer := 1;
   constant C_REG_WRITE    : integer := 0;

   -- Bypass logic
   signal reg_we_d      : std_logic;
   signal reg_addr_d    : std_logic_vector(3 downto 0);
   signal reg_val_d     : std_logic_vector(15 downto 0);
   signal dec_src_val   : std_logic_vector(15 downto 0);
   signal dec_dst_val   : std_logic_vector(15 downto 0);
   signal dec_r14       : std_logic_vector(15 downto 0);

   -- ALU
   signal alu_oper      : std_logic_vector(3 downto 0);
   signal alu_flags     : std_logic_vector(15 downto 0);
   signal alu_src_val   : std_logic_vector(15 downto 0);
   signal alu_dst_val   : std_logic_vector(15 downto 0);
   signal alu_res_flags : std_logic_vector(15 downto 0);
   signal alu_res_data  : std_logic_vector(16 downto 0);

   signal wait_for_mem_access : std_logic;
   signal wait_for_mem_src    : std_logic;
   signal wait_for_mem_dst    : std_logic;

begin

   dec_ready_o <= not (wait_for_mem_src or wait_for_mem_dst or wait_for_mem_access);

   wait_for_mem_src    <= dec_valid_i and dec_microop_i(C_MEM_ALU_SRC) and not mem_src_valid_i;
   wait_for_mem_dst    <= dec_valid_i and dec_microop_i(C_MEM_ALU_DST) and not mem_dst_valid_i;
   wait_for_mem_access <= dec_valid_i and (dec_microop_i(C_MEM_ALU_DST) or
                                           dec_microop_i(C_MEM_READ_SRC) or
                                           dec_microop_i(C_MEM_READ_DST)) and not mem_ready_i;

   mem_src_ready_o <= dec_microop_i(C_MEM_ALU_SRC);
   mem_dst_ready_o <= dec_microop_i(C_MEM_ALU_DST);


   ------------------------------------------------------------
   -- Bypass logic
   ------------------------------------------------------------

   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         reg_val_d  <= reg_val_o;
         reg_we_d   <= reg_we_o;
         reg_addr_d <= reg_addr_o;
      end if;
   end process p_delay;

   dec_src_val <= reg_val_d when reg_we_d = '1' and reg_addr_d = dec_src_addr_i else
                  dec_src_val_i;
   dec_dst_val <= reg_val_d when reg_we_d = '1' and reg_addr_d = dec_dst_addr_i else
                  dec_dst_val_i;
   dec_r14     <= reg_val_d when reg_we_d = '1' and reg_addr_d = C_REG_SR else
                  dec_r14_i;


   ------------------------------------------------------------
   -- ALU
   ------------------------------------------------------------

   alu_oper    <= dec_opcode_i;
   alu_flags   <= dec_r14;
   alu_src_val <= mem_src_data_i when dec_microop_i(C_MEM_ALU_SRC) = '1' else dec_src_val;
   alu_dst_val <= mem_dst_data_i when dec_microop_i(C_MEM_ALU_DST) = '1' else dec_dst_val;

   i_alu_data : entity work.alu_data
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         opcode_i   => alu_oper,
         sr_i       => alu_flags,
         src_data_i => alu_src_val,
         dst_data_i => alu_dst_val,
         res_data_o => alu_res_data
      ); -- i_alu_data

   i_alu_flags : entity work.alu_flags
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         opcode_i   => alu_oper,
         sr_i       => alu_flags,
         src_data_i => alu_src_val,
         dst_data_i => alu_dst_val,
         res_data_i => alu_res_data,
         sr_o       => alu_res_flags
      ); -- i_alu_flags


   reg_r14_o      <= alu_res_flags;
   reg_r14_we_o   <= dec_r14_we_i and dec_valid_i and dec_ready_o;

   reg_addr_o     <= dec_reg_addr_i;
   reg_val_o      <= alu_res_data(15 downto 0);
   reg_we_o       <= dec_valid_i and dec_ready_o and dec_microop_i(C_REG_WRITE);

   mem_valid_o    <= dec_valid_i and not (wait_for_mem_src or wait_for_mem_dst) and or(dec_microop_i(3 downto 1));
   mem_op_o       <= dec_microop_i(3 downto 1);
   mem_addr_o     <= dec_src_val when dec_microop_i(3) = '1' else dec_dst_val;
   mem_wr_data_o  <= alu_res_data(15 downto 0);

end architecture synthesis;

