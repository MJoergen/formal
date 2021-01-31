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
      exe_src_val_o   : out std_logic_vector(15 downto 0);
      exe_dst_val_o   : out std_logic_vector(15 downto 0);
      exe_reg_addr_o  : out std_logic_vector(3 downto 0);
      exe_mem_addr_o  : out std_logic_vector(15 downto 0)
   );
end entity decode;

architecture synthesis of decode is

   -- Instruction format
   subtype R_OPCODE    is natural range 15 downto 12;
   subtype R_SRC_REG   is natural range 11 downto  8;
   subtype R_SRC_MODE  is natural range  7 downto  6;
   subtype R_DST_REG   is natural range  5 downto  2;
   subtype R_DST_MODE  is natural range  1 downto  0;   
   subtype R_JMP_MODE  is natural range  5 downto  4;
   constant R_JMP_NEG  : integer := 3;
   subtype R_JMP_COND  is natural range  2 downto  0;

   constant C_OPCODE_MOVE : std_logic_vector(3 downto 0) := X"0"; -- Does not read dst
   constant C_OPCODE_ADD  : std_logic_vector(3 downto 0) := X"1";
   constant C_OPCODE_ADDC : std_logic_vector(3 downto 0) := X"2";
   constant C_OPCODE_SUB  : std_logic_vector(3 downto 0) := X"3";
   constant C_OPCODE_SUBC : std_logic_vector(3 downto 0) := X"4";
   constant C_OPCODE_SHL  : std_logic_vector(3 downto 0) := X"5";
   constant C_OPCODE_SHR  : std_logic_vector(3 downto 0) := X"6";
   constant C_OPCODE_SWAP : std_logic_vector(3 downto 0) := X"7"; -- Does not read dst
   constant C_OPCODE_NOT  : std_logic_vector(3 downto 0) := X"8"; -- Does not read dst
   constant C_OPCODE_AND  : std_logic_vector(3 downto 0) := X"9";
   constant C_OPCODE_OR   : std_logic_vector(3 downto 0) := X"A";
   constant C_OPCODE_XOR  : std_logic_vector(3 downto 0) := X"B";
   constant C_OPCODE_CMP  : std_logic_vector(3 downto 0) := X"C"; -- Does not write dst
   constant C_OPCODE_RES  : std_logic_vector(3 downto 0) := X"D";
   constant C_OPCODE_CTRL : std_logic_vector(3 downto 0) := X"E";
   constant C_OPCODE_JMP  : std_logic_vector(3 downto 0) := X"F";

   constant C_MODE_REG : std_logic_vector(1 downto 0) := "00"; -- R
   constant C_MODE_MEM : std_logic_vector(1 downto 0) := "01"; -- @R
   constant C_MODE_INC : std_logic_vector(1 downto 0) := "10"; -- @R++
   constant C_MODE_DEC : std_logic_vector(1 downto 0) := "11"; -- @--R

   constant C_JMPMODE_ABRA : std_logic_vector(1 downto 0) := "00";
   constant C_JMPMODE_ASUB : std_logic_vector(1 downto 0) := "01";
   constant C_JMPMODE_RBRA : std_logic_vector(1 downto 0) := "10";
   constant C_JMPMODE_RSUB : std_logic_vector(1 downto 0) := "11";

   signal immediate    : std_logic;
   signal wait_src_val : std_logic;

   signal count        : std_logic_vector(1 downto 0);
   signal fetch_data_d : std_logic_vector(15 downto 0);
   signal fetch_data   : std_logic_vector(15 downto 0);


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

   p_fetch_data : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if count = 0 then
            fetch_data_d <= fetch_data_i;
         end if;
      end if;
   end process p_fetch_data;

   fetch_data <= fetch_data_i when count = 0 else fetch_data_d;


   -- Special case when src = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".
   immediate <= '1' when fetch_data(R_SRC_REG) = "1111" and fetch_data(R_SRC_MODE) = C_MODE_INC
           else '0';

   reg_src_addr_o <= fetch_data(R_SRC_REG);
   reg_dst_addr_o <= fetch_data(R_DST_REG);

   fetch_ready_o <= exe_ready_i when count = 0
               else wait_src_val;


   microcode_addr(C_READ_DST)  <= '0' when fetch_data(R_OPCODE) = C_OPCODE_MOVE or
                                           fetch_data(R_OPCODE) = C_OPCODE_SWAP or
                                           fetch_data(R_OPCODE) = C_OPCODE_NOT or
                                           fetch_data(R_OPCODE) = C_OPCODE_JMP else '1';
   microcode_addr(C_WRITE_DST) <= '0' when fetch_data(R_OPCODE) = C_OPCODE_CMP or
                                           fetch_data(R_OPCODE) = C_OPCODE_JMP else '1';
   microcode_addr(C_MEM_SRC)   <= '0' when fetch_data(R_SRC_MODE) = C_MODE_REG else '1';
   microcode_addr(C_MEM_DST)   <= '0' when fetch_data(R_DST_MODE) = C_MODE_REG else '1';
   microcode_addr(R_COUNT)     <= count;

   i_microcode : entity work.microcode
      port map (
         addr_i  => microcode_addr,
         value_o => microcode_value
      ); -- i_microcode


   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if exe_ready_i = '1' then
            exe_valid_o    <= '0';
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_src_val_o  <= (others => '0');
            exe_dst_val_o  <= (others => '0');
            exe_reg_addr_o <= (others => '0');
            exe_mem_addr_o <= (others => '0');
         end if;

         if (count > 0 and exe_ready_i = '1' and wait_src_val = '0') or (fetch_valid_i = '1' and fetch_ready_o = '1') then
            exe_opcode_o   <= fetch_data(R_OPCODE);
            exe_src_val_o  <= reg_src_val_i;
            exe_dst_val_o  <= reg_dst_val_i;
            exe_flags_o    <= reg_flags_i;
            exe_reg_addr_o <= fetch_data(R_DST_REG);

            if microcode_value(C_MEM_READ_SRC) = '1' then
               exe_mem_addr_o <= reg_src_val_i;
            else
               exe_mem_addr_o <= reg_dst_val_i;
            end if;

            exe_microop_o <= microcode_value(5 downto 0);
            exe_valid_o   <= '1';

            if fetch_data(R_OPCODE) = C_OPCODE_JMP then
               exe_microop_o <= (others => '0');
               exe_microop_o(C_REG_WRITE) <= reg_flags_i(to_integer(fetch_data(R_JMP_COND))) xor fetch_data(R_JMP_NEG);
               exe_reg_addr_o <= "1111"; -- R15 = PC

               if fetch_data(R_JMP_MODE) = C_JMPMODE_RBRA or fetch_data(R_JMP_MODE) = C_JMPMODE_RSUB then
                  exe_opcode_o  <= C_OPCODE_ADDC;
                  exe_dst_val_o <= fetch_addr_i;
                  exe_flags_o(C_FLAGS_CARRY) <= '1';
               end if;
            end if;

            if fetch_data(R_OPCODE) = C_OPCODE_CTRL then
               assert false report "CTRL instruction at address " & to_hstring(fetch_addr_i) severity failure;
            end if;

            if microcode_value(C_LAST) = '1' then
               count <= "00";
            else
               count <= count + 1;
            end if;

            if count = 0 and immediate = '1' then
               exe_valid_o    <= '0';
               exe_microop_o  <= (others => '0');
               exe_opcode_o   <= (others => '0');
               exe_src_val_o  <= (others => '0');
               exe_dst_val_o  <= (others => '0');
               exe_reg_addr_o <= (others => '0');
               exe_mem_addr_o <= (others => '0');
               wait_src_val   <= '1';
            elsif wait_src_val = '1' then
               wait_src_val  <= '0';
               exe_src_val_o <= fetch_data_i;
               exe_microop_o(C_MEM_ALU_SRC) <= '0';
            end if;
         end if;

         if rst_i = '1' then
            wait_src_val   <= '0';
            count          <= (others => '0');
            exe_valid_o    <= '0';
            exe_microop_o  <= (others => '0');
            exe_opcode_o   <= (others => '0');
            exe_src_val_o  <= (others => '0');
            exe_dst_val_o  <= (others => '0');
            exe_reg_addr_o <= (others => '0');
            exe_mem_addr_o <= (others => '0');
         end if;
      end if;
   end process p_fsm;

end architecture synthesis;

