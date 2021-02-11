library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- Read src and dst register values and pass on to next stage
-- Generate sequence of microops:
-- * MEM_READ_SRC : Read source operand from memory
-- * MEM_READ_DST : Read destination operand from memory
-- * MEM_ALU_SRC  : Wait for source operand from memory
-- * MEM_ALU_DST  : Wait for destination operand from memory
-- * MEM_WRITE    : Write result to memory
-- * REG_WRITE    : Write result to register
-- Other information passed on is:
-- * Opcode
-- * Source register address
-- * Source register value
-- * Destination register address
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

      -- Register file. Value arrives on the next clock cycle
      reg_src_addr_o  : out std_logic_vector(3 downto 0);
      reg_dst_addr_o  : out std_logic_vector(3 downto 0);
      reg_src_val_i   : in  std_logic_vector(15 downto 0);
      reg_dst_val_i   : in  std_logic_vector(15 downto 0);
      reg_r14_i       : in  std_logic_vector(15 downto 0);

      -- To Execute stage
      exe_valid_o     : out std_logic;
      exe_ready_i     : in  std_logic;
      exe_microop_o   : out std_logic_vector(7 downto 0);
      exe_opcode_o    : out std_logic_vector(3 downto 0);
      exe_jmp_mode_o  : out std_logic_vector(1 downto 0);
      exe_jmp_cond_o  : out std_logic_vector(2 downto 0);
      exe_jmp_neg_o   : out std_logic;
      exe_ctrl_o      : out std_logic_vector(5 downto 0);

      exe_r14_o       : out std_logic_vector(15 downto 0);
      exe_r14_we_o    : out std_logic;

      exe_src_addr_o  : out std_logic_vector(3 downto 0);
      exe_src_val_o   : out std_logic_vector(15 downto 0);
      exe_src_mode_o  : out std_logic_vector(1 downto 0);
      exe_dst_addr_o  : out std_logic_vector(3 downto 0);
      exe_dst_val_o   : out std_logic_vector(15 downto 0);
      exe_dst_mode_o  : out std_logic_vector(1 downto 0);
      exe_reg_addr_o  : out std_logic_vector(3 downto 0)
   );
end entity decode;

architecture synthesis of decode is

   signal count          : std_logic_vector(1 downto 0);
   signal instruction_r  : std_logic_vector(15 downto 0);
   signal instruction    : std_logic_vector(15 downto 0);

   signal instruction_d  : std_logic_vector(15 downto 0);
   signal fetch_addr_d   : std_logic_vector(15 downto 0);
   signal wait_src_val_d : std_logic;
   signal wait_dst_val_d : std_logic;

   signal immediate_src  : std_logic;
   signal immediate_dst  : std_logic;
   signal wait_src_val   : std_logic;
   signal wait_dst_val   : std_logic;


   signal src_operand    : std_logic;
   signal dst_operand    : std_logic;

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
   -- bit 8 : last
   -- bit 7 : update src reg
   -- bit 6 : update dst reg
   -- bit 5 : mem to alu src
   -- bit 4 : mem to alu dst
   -- bit 3 : mem read to src
   -- bit 2 : mem read to dst
   -- bit 1 : mem write
   -- bit 0 : reg write
   signal microcode_value : std_logic_vector(8 downto 0);
   signal microcode_value_d : std_logic_vector(8 downto 0);

   constant C_LAST         : integer := 8;
   constant C_REG_MOD_SRC  : integer := 7;
   constant C_REG_MOD_DST  : integer := 6;
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

   signal osf_in_valid  : std_logic;
   signal osf_in_data   : std_logic_vector(16 downto 0);
   signal osf_out_ready : std_logic;
   signal osf_out_valid : std_logic;
   signal osf_out_data  : std_logic_vector(16 downto 0);

   constant C_HAS_SRC_OPERAND : std_logic_vector(15 downto 0) := (
      C_OPCODE_CTRL => '0',
      others        => '1');

   constant C_HAS_DST_OPERAND : std_logic_vector(15 downto 0) := (
      C_OPCODE_JMP  => '0',
      others        => '1');

   constant C_READS_FROM_DST : std_logic_vector(15 downto 0) := (
      C_OPCODE_MOVE => '0',
      C_OPCODE_SWAP => '0',
      C_OPCODE_NOT  => '0',
      C_OPCODE_CTRL => '0',
      C_OPCODE_JMP  => '0',
      others        => '1');

   constant C_WRITES_TO_DST : std_logic_vector(15 downto 0) := (
      C_OPCODE_CMP  => '0',
      C_OPCODE_CTRL => '0',
      C_OPCODE_JMP  => '0',
      others        => '1');

begin

   fetch_ready_o <= exe_ready_i when count = 0
               else (wait_src_val or wait_dst_val);


   ------------------------------------------------------------
   -- Latch instruction
   ------------------------------------------------------------

   p_fetch_data : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if count = 0 then
            instruction_r <= fetch_data_i;
         end if;
      end if;
   end process p_fetch_data;

   instruction <= fetch_data_i when count = 0 else instruction_r;


   ------------------------------------------------------------
   -- Instruction format decoding
   ------------------------------------------------------------

   src_operand <= C_HAS_SRC_OPERAND(to_integer(instruction(R_OPCODE)));
   dst_operand <= C_HAS_DST_OPERAND(to_integer(instruction(R_OPCODE)));


   ------------------------------------------------------------
   -- Microcode lookup (combinatorial)
   ------------------------------------------------------------

   microcode_addr(C_READ_DST)  <= C_READS_FROM_DST(to_integer(instruction(R_OPCODE)));
   microcode_addr(C_WRITE_DST) <= C_WRITES_TO_DST(to_integer(instruction(R_OPCODE)));
   microcode_addr(C_MEM_SRC)   <= '0' when instruction(R_SRC_MODE) = C_MODE_REG else src_operand;
   microcode_addr(C_MEM_DST)   <= '0' when instruction(R_DST_MODE) = C_MODE_REG else dst_operand;
   microcode_addr(R_COUNT)     <= count;

   i_microcode : entity work.microcode
      port map (
         addr_i  => microcode_addr,
         value_o => microcode_value
      ); -- i_microcode


   ------------------------------------------------------------
   -- Read from register file
   ------------------------------------------------------------

   reg_src_addr_o <= instruction(R_SRC_REG);
   reg_dst_addr_o <= to_stdlogicvector(C_REG_SP, 4) when count > 0 and
                                                         microcode_value_d(C_LAST) = '1' and
                                                         instruction_d(R_OPCODE) = C_OPCODE_JMP and
                                                         (instruction_d(R_JMP_MODE) = C_JMP_ASUB or instruction_d(R_JMP_MODE) = C_JMP_RSUB) else
                     instruction(R_DST_REG);


   ------------------------------------------------------------
   -- Generate operand values (combinatorial)
   ------------------------------------------------------------

   exe_src_val_o <= fetch_addr_d when instruction_d(R_OPCODE) = C_OPCODE_JMP and
                                     (instruction_d(R_JMP_MODE) = C_JMP_ASUB or instruction_d(R_JMP_MODE) = C_JMP_RSUB) and
                                      count = 0 else
                    osf_out_data(15 downto 0) when osf_out_valid and osf_out_data(16) else
                    fetch_addr_i when exe_src_addr_o = C_REG_PC else
                    reg_src_val_i;

   exe_dst_val_o <= fetch_addr_i when exe_reg_addr_o = C_REG_PC and exe_microop_o(C_REG_WRITE) = '1' else
                    fetch_addr_d when instruction_d(R_OPCODE) = C_OPCODE_JMP and
                                     (instruction_d(R_JMP_MODE) = C_JMP_RBRA or instruction_d(R_JMP_MODE) = C_JMP_RSUB) and
                                      count > 0 and
                                      microcode_value_d(C_LAST) = '1' else
                    osf_out_data(15 downto 0) when osf_out_valid and not osf_out_data(16) else
                    reg_dst_val_i;

   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         instruction_d  <= instruction;
         fetch_addr_d   <= fetch_addr_i;
         wait_src_val_d <= wait_src_val;
         wait_dst_val_d <= wait_dst_val;
      end if;
   end process p_delay;

   osf_in_valid <= wait_src_val or wait_dst_val;
   osf_in_data  <= wait_src_val & fetch_data_i;
   osf_out_ready <= '1' when count = 0 else '0';   -- Clear when new instruction begins.

   i_one_stage_fifo : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 17
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => osf_in_valid,
         s_ready_o => open, -- ignore
         s_data_i  => osf_in_data,
         m_valid_o => osf_out_valid,
         m_ready_i => osf_out_ready,
         m_data_o  => osf_out_data
      ); -- i_one_stage_fifo


   ------------------------------------------------------------
   -- Processing of immediate values, e.g. the instruction CMP @R1, @PC++.
   -- Nominally, the instruction CMP @R, @R performs the following three operations:
   --   C_MEM_READ_SRC
   --   C_MEM_READ_DST
   --   C_MEM_ALU_SRC + C_MEM_ALU_DST
   -- However, in the above case this should reduce to:
   --   C_MEM_READ_SRC
   --   NOP
   --   C_MEM_ALU_SRC
   -- or ideally into the even simpler
   --   C_MEM_READ_SRC
   --   C_MEM_ALU_SRC


   ------------------------------------------------------------

   -- Special case when src = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".
   immediate_src <= '1' when instruction(R_SRC_REG) = "1111" and instruction(R_SRC_MODE) = C_MODE_POST
               else '0';

   -- Special case when dst = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".
   immediate_dst <= '1' when instruction(R_DST_REG) = "1111" and instruction(R_DST_MODE) = C_MODE_POST
               else '0';


   ------------------------------------------------------------
   -- Generate remaining output values
   ------------------------------------------------------------

   p_output2exe : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if exe_ready_i = '1' then
            exe_valid_o    <= '0';
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_jmp_mode_o <= (others => '0');
            exe_jmp_cond_o <= (others => '0');
            exe_jmp_neg_o  <= '0';
            exe_ctrl_o     <= (others => '0');
            exe_r14_o      <= (others => '0');
            exe_r14_we_o   <= '0';
            exe_src_addr_o <= (others => '0');
            exe_src_mode_o <= (others => '0');
            exe_dst_addr_o <= (others => '0');
            exe_dst_mode_o <= (others => '0');
            exe_reg_addr_o <= (others => '0');
         end if;

         exe_src_addr_o    <= instruction(R_SRC_REG);
         exe_dst_addr_o    <= instruction(R_DST_REG);

         exe_src_mode_o    <= "00";
         exe_dst_mode_o    <= "00";
         if src_operand then
            exe_src_mode_o <= instruction(R_SRC_MODE);
         end if;
         if dst_operand then
            exe_dst_mode_o <= instruction(R_DST_MODE);
         end if;

         if (count > 0 and exe_ready_i = '1' and wait_src_val = '0' and wait_dst_val = '0')
            or (fetch_valid_i = '1' and fetch_ready_o = '1') then
            exe_opcode_o   <= instruction(R_OPCODE);
            exe_jmp_mode_o <= instruction(R_JMP_MODE);
            exe_jmp_cond_o <= instruction(R_JMP_COND);
            exe_jmp_neg_o  <= instruction(R_JMP_NEG);
            exe_ctrl_o     <= instruction(R_CTRL_CMD);
            exe_r14_o      <= reg_r14_i;
            exe_r14_we_o   <= '1';
            exe_reg_addr_o <= instruction(R_DST_REG);
            exe_microop_o  <= microcode_value(7 downto 0);
            exe_valid_o    <= '1';

            -- Jump instructions are translated into simple register writes to R15.
            if instruction(R_OPCODE) = C_OPCODE_JMP and microcode_value(C_LAST) = '1' and
                  (count = 0 or microcode_value_d(C_LAST) = '0') then
               exe_microop_o(C_REG_WRITE) <= '1';
               exe_reg_addr_o <= to_stdlogicvector(C_REG_PC, 4);
               exe_r14_we_o   <= '0';
            end if;

            if microcode_value(C_LAST) = '1' then
               count <= "00";
            else
               count <= count + 1;
            end if;

            -- Artifically introduce a NOP in case of a JMP.
            if instruction(R_OPCODE) = C_OPCODE_JMP then
               microcode_value_d <= microcode_value;
               if count = 0 or microcode_value_d(C_LAST) = '0' then
                  count <= count + 1;
               else
                  exe_valid_o    <= '0';
                  exe_microop_o  <= (others => '0');
                  exe_opcode_o   <= (others => '0');
                  exe_jmp_mode_o <= (others => '0');
                  exe_jmp_cond_o <= (others => '0');
                  exe_jmp_neg_o  <= '0';
                  exe_ctrl_o     <= (others => '0');
                  exe_r14_o      <= (others => '0');
                  exe_r14_we_o   <= '0';
                  exe_src_addr_o <= (others => '0');
                  exe_src_mode_o <= (others => '0');
                  exe_dst_addr_o <= (others => '0');
                  exe_dst_mode_o <= (others => '0');
                  exe_reg_addr_o <= (others => '0');

                  -- Subroutine calls are special.
                  -- Artifically introduce a MOVE R15, @--R13
                  if instruction(R_JMP_MODE) = C_JMP_ASUB or
                     instruction(R_JMP_MODE) = C_JMP_RSUB then

                     exe_valid_o    <= '1';
                     exe_r14_o      <= reg_r14_i;
                     exe_r14_we_o   <= '0';
                     exe_microop_o  <= "01000010"; -- C_MEM_WRITE or C_REG_MOD_DST;
                     exe_opcode_o   <= to_stdlogicvector(C_OPCODE_JMP, 4);
                     exe_jmp_mode_o <= instruction(R_JMP_MODE);
                     exe_jmp_cond_o <= instruction(R_JMP_COND);
                     exe_jmp_neg_o  <= instruction(R_JMP_NEG);
                     exe_ctrl_o     <= instruction(R_CTRL_CMD);
                     exe_dst_addr_o <= to_stdlogicvector(C_REG_SP, 4);
                     exe_dst_mode_o <= to_stdlogicvector(C_MODE_PRE, 2);
                     exe_reg_addr_o <= to_stdlogicvector(C_REG_SP, 4);
                  end if;
               end if;
            end if;

            if microcode_value(C_MEM_READ_SRC) = '1' and immediate_src = '1' then
               exe_valid_o    <= '0';
               exe_microop_o  <= (others => '0');
               exe_opcode_o   <= (others => '0');
               exe_jmp_mode_o <= (others => '0');
               exe_jmp_cond_o <= (others => '0');
               exe_jmp_neg_o  <= '0';
               exe_ctrl_o     <= (others => '0');
               exe_r14_o      <= (others => '0');
               exe_r14_we_o   <= '0';
               exe_src_addr_o <= (others => '0');
               exe_src_mode_o <= (others => '0');
               exe_dst_addr_o <= (others => '0');
               exe_dst_mode_o <= (others => '0');
               exe_reg_addr_o <= (others => '0');
               wait_src_val   <= '1';
            elsif wait_src_val = '1' then
               wait_src_val  <= '0';
            end if;

            if microcode_value(C_MEM_READ_DST) = '1' and immediate_dst = '1' then
               exe_valid_o    <= '0';
               exe_microop_o  <= (others => '0');
               exe_opcode_o   <= (others => '0');
               exe_jmp_mode_o <= (others => '0');
               exe_jmp_cond_o <= (others => '0');
               exe_jmp_neg_o  <= '0';
               exe_ctrl_o     <= (others => '0');
               exe_r14_o      <= (others => '0');
               exe_r14_we_o   <= '0';
               exe_src_addr_o <= (others => '0');
               exe_src_mode_o <= (others => '0');
               exe_dst_addr_o <= (others => '0');
               exe_dst_mode_o <= (others => '0');
               exe_reg_addr_o <= (others => '0');
               wait_dst_val   <= '1';
            elsif wait_dst_val = '1' then
               wait_dst_val  <= '0';
            end if;

            if immediate_src = '1' then
               exe_microop_o(C_MEM_ALU_SRC) <= '0';
               exe_src_mode_o <= "00";
            end if;

            if immediate_dst = '1' then
               exe_microop_o(C_MEM_ALU_DST) <= '0';
               exe_dst_mode_o <= "00";
            end if;
         end if;

         if rst_i = '1' then
            wait_src_val   <= '0';
            wait_dst_val   <= '0';
            count          <= (others => '0');
            exe_valid_o    <= '0';
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_jmp_mode_o <= (others => '0');
            exe_jmp_cond_o <= (others => '0');
            exe_jmp_neg_o  <= '0';
            exe_ctrl_o     <= (others => '0');
            exe_r14_o      <= (others => '0');
            exe_r14_we_o   <= '0';
            exe_src_addr_o <= (others => '0');
            exe_src_mode_o <= (others => '0');
            exe_dst_addr_o <= (others => '0');
            exe_dst_mode_o <= (others => '0');
            exe_reg_addr_o <= (others => '0');
         end if;
      end if;
   end process p_output2exe;

end architecture synthesis;

