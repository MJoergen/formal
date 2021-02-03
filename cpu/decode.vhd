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

entity decode is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From Instruction fetch
      fetch_valid_i   : in  std_logic;
      fetch_ready_o   : out std_logic;
      fetch_addr_i    : in  std_logic_vector(15 downto 0);
      fetch_data_i    : in  std_logic_vector(15 downto 0);

      -- Register file
      reg_src_addr_o  : out std_logic_vector(3 downto 0);
      reg_dst_addr_o  : out std_logic_vector(3 downto 0);
      reg_src_val_i   : in  std_logic_vector(15 downto 0);
      reg_dst_val_i   : in  std_logic_vector(15 downto 0);
      reg_flags_i     : in  std_logic_vector(15 downto 0);

      -- To Execute stage
      exe_valid_o     : out std_logic;
      exe_ready_i     : in  std_logic;
      exe_microop_o   : out std_logic_vector(5 downto 0);
      exe_opcode_o    : out std_logic_vector(3 downto 0);
      exe_flags_o     : out std_logic_vector(15 downto 0);
      exe_flags_we_o  : out std_logic;
      exe_src_addr_o  : out std_logic_vector(3 downto 0);
      exe_src_val_o   : out std_logic_vector(15 downto 0);
      exe_dst_addr_o  : out std_logic_vector(3 downto 0);
      exe_dst_val_o   : out std_logic_vector(15 downto 0);
      exe_reg_addr_o  : out std_logic_vector(3 downto 0)
   );
end entity decode;

architecture synthesis of decode is

   signal immediate_src  : std_logic;
   signal immediate_dst  : std_logic;
   signal wait_src_val   : std_logic;
   signal wait_dst_val   : std_logic;

   signal fetch_addr_r   : std_logic_vector(15 downto 0);
   signal fetch_data_r   : std_logic_vector(15 downto 0);
   signal wait_src_val_r : std_logic;
   signal wait_dst_val_r : std_logic;

   signal count          : std_logic_vector(1 downto 0);
   signal instruction_r  : std_logic_vector(15 downto 0);
   signal instruction    : std_logic_vector(15 downto 0);
   signal instruction_d  : std_logic_vector(15 downto 0);


   -- microcode address bitmap:
   -- bit  5   : read from dst
   -- bit  4   : write to dst
   -- bit  3   : src mem
   -- bit  2   : dst mem
   -- bits 1-0 : count
   signal microcode_addr  : std_logic_vector(5 downto 0);

   constant C_READ_DST  : integer := 5;
   constant C_WRITE_DST : integer := 4;
   constant C_MEM_SRC   : integer := 3;
   constant C_MEM_DST   : integer := 2;
   subtype R_COUNT is natural range 1 downto 0;

   -- microcode value bitmap
   -- bit 6 : last
   -- bit 5 : mem to alu src
   -- bit 4 : mem to alu dst
   -- bit 3 : mem read to src
   -- bit 2 : mem read to dst
   -- bit 1 : mem write
   -- bit 0 : reg write
   signal microcode_value : std_logic_vector(6 downto 0);
   signal microcode_value_d : std_logic_vector(6 downto 0);

   constant C_LAST         : integer := 6;
   constant C_MEM_ALU_SRC  : integer := 5;
   constant C_MEM_ALU_DST  : integer := 4;
   constant C_MEM_READ_SRC : integer := 3;
   constant C_MEM_READ_DST : integer := 2;
   constant C_MEM_WRITE    : integer := 1;
   constant C_REG_WRITE    : integer := 0;

   constant C_FLAGS_ONE   : integer := 0;
   constant C_FLAGS_X     : integer := 1;
   constant C_FLAGS_CARRY : integer := 2;
   constant C_FLAGS_ZERO  : integer := 3;
   constant C_FLAGS_NEG   : integer := 4;
   constant C_FLAGS_OVERF : integer := 5;

begin

   fetch_ready_o <= exe_ready_i when count = 0
               else (wait_src_val or wait_dst_val);


   p_fetch_data_2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fetch_data_r   <= fetch_data_i;
         fetch_addr_r   <= fetch_addr_i;
         wait_src_val_r <= wait_src_val;
         wait_dst_val_r <= wait_dst_val;
      end if;
   end process p_fetch_data_2;

   exe_src_val_o <= fetch_data_r when wait_src_val_r = '1' and wait_src_val = '0' else reg_src_val_i;
   exe_dst_val_o <= fetch_addr_r when instruction_d(R_OPCODE) = C_OPCODE_JMP and
                                      (instruction_d(R_JMP_MODE) = C_JMP_RBRA or instruction_d(R_JMP_MODE) = C_JMP_RSUB)
               else fetch_data_r when wait_dst_val_r = '1' and wait_dst_val = '0' else reg_dst_val_i;


   p_fetch_data : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if count = 0 then
            instruction_r <= fetch_data_i;
         end if;

         instruction_d <= instruction;
      end if;
   end process p_fetch_data;

   instruction <= fetch_data_i when count = 0 else instruction_r;


   reg_src_addr_o <= instruction(R_SRC_REG);
   reg_dst_addr_o <= instruction(R_DST_REG);

   p_addr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         exe_src_addr_o <= instruction(R_SRC_REG);
         exe_dst_addr_o <= instruction(R_DST_REG);
      end if;
   end process p_addr;



   microcode_addr(C_READ_DST)  <= '0' when instruction(R_OPCODE) = C_OPCODE_MOVE or
                                           instruction(R_OPCODE) = C_OPCODE_SWAP or
                                           instruction(R_OPCODE) = C_OPCODE_NOT or
                                           instruction(R_OPCODE) = C_OPCODE_JMP else '1';
   microcode_addr(C_WRITE_DST) <= '0' when instruction(R_OPCODE) = C_OPCODE_CMP or
                                           instruction(R_OPCODE) = C_OPCODE_JMP else '1';
   microcode_addr(C_MEM_SRC)   <= '0' when instruction(R_SRC_MODE) = C_MODE_REG else '1';
   microcode_addr(C_MEM_DST)   <= '0' when instruction(R_DST_MODE) = C_MODE_REG else '1';
   microcode_addr(R_COUNT)     <= count;

   i_microcode : entity work.microcode
      port map (
         addr_i  => microcode_addr,
         value_o => microcode_value
      ); -- i_microcode


   -- Special case when src = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".
   immediate_src <= '1' when instruction(R_SRC_REG) = "1111" and instruction(R_SRC_MODE) = C_MODE_POST
               else '0';

   -- Special case when dst = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".
   immediate_dst <= '1' when instruction(R_DST_REG) = "1111" and instruction(R_DST_MODE) = C_MODE_POST
               else '0';

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         microcode_value_d <= microcode_value;

         if exe_ready_i = '1' then
            exe_valid_o    <= '0';
            exe_flags_we_o <= '0';
            exe_flags_o    <= (others => '0');
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_reg_addr_o <= (others => '0');
         end if;

         if (count > 0 and exe_ready_i = '1' and wait_src_val = '0' and wait_dst_val = '0')
            or (fetch_valid_i = '1' and fetch_ready_o = '1') then
            exe_opcode_o   <= instruction(R_OPCODE);
            exe_flags_o    <= reg_flags_i;
            exe_flags_we_o <= '1';
            exe_reg_addr_o <= instruction(R_DST_REG);

            exe_microop_o <= microcode_value(5 downto 0);
            exe_valid_o   <= '1';

            if instruction(R_OPCODE) = C_OPCODE_JMP then
               exe_microop_o <= (others => '0');
               exe_microop_o(C_REG_WRITE) <= reg_flags_i(to_integer(instruction(R_JMP_COND))) xor instruction(R_JMP_NEG);
               exe_reg_addr_o <= "1111"; -- R15 = PC
               exe_flags_we_o <= '0';

               if instruction(R_JMP_MODE) = C_JMP_RBRA or instruction(R_JMP_MODE) = C_JMP_RSUB then
                  exe_opcode_o <= to_stdlogicvector(C_OPCODE_ADDC, 4);
                  exe_flags_o(C_FLAGS_CARRY) <= '1';
               end if;
            end if;

            if instruction(R_OPCODE) = C_OPCODE_CTRL then
               assert false report "CTRL instruction at address " & to_hstring(fetch_addr_i) severity failure;
            end if;

            if microcode_value(C_LAST) = '1' then
               count <= "00";
            else
               count <= count + 1;
            end if;

            if count = 0 and immediate_src = '1' then
               exe_valid_o    <= '0';
               exe_flags_we_o <= '0';
               exe_flags_o    <= (others => '0');
               exe_microop_o  <= (others => '0');
               exe_opcode_o   <= (others => '0');
               exe_reg_addr_o <= (others => '0');
               wait_src_val   <= '1';
            elsif wait_src_val = '1' then
               wait_src_val  <= '0';
               exe_microop_o(C_MEM_ALU_SRC) <= '0';
            end if;

            if count = 0 and immediate_dst = '1' then
               exe_valid_o    <= '0';
               exe_flags_we_o <= '0';
               exe_flags_o    <= (others => '0');
               exe_microop_o  <= (others => '0');
               exe_opcode_o   <= (others => '0');
               exe_reg_addr_o <= (others => '0');
               wait_dst_val   <= '1';
            elsif wait_dst_val = '1' then
               wait_dst_val  <= '0';
               exe_microop_o(C_MEM_ALU_DST) <= '0';
            end if;
         end if;

         if rst_i = '1' then
            wait_src_val   <= '0';
            wait_dst_val   <= '0';
            count          <= (others => '0');
            exe_valid_o    <= '0';
            exe_flags_we_o <= '0';
            exe_flags_o    <= (others => '0');
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_reg_addr_o <= (others => '0');
         end if;
      end if;
   end process p_fsm;

end architecture synthesis;

