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

      -- To Instruction fetch
      fetch_valid_o   : out std_logic;
      fetch_addr_o    : out std_logic_vector(15 downto 0);

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

   constant C_LAST         : integer := 6;
   constant C_MEM_ALU_SRC  : integer := 5;
   constant C_MEM_ALU_DST  : integer := 4;
   constant C_MEM_READ_SRC : integer := 3;
   constant C_MEM_READ_DST : integer := 2;
   constant C_MEM_WRITE    : integer := 1;
   constant C_REG_WRITE    : integer := 0;

   constant C_MODE_REG : std_logic_vector(1 downto 0) := "00"; -- R
   constant C_MODE_MEM : std_logic_vector(1 downto 0) := "01"; -- @R
   constant C_MODE_INC : std_logic_vector(1 downto 0) := "10"; -- @R++
   constant C_MODE_DEC : std_logic_vector(1 downto 0) := "11"; -- @--R

   signal immediate    : std_logic;
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

   -- microcode value bitmap
   -- bit 4 : last
   -- bit 3 : mem read to src
   -- bit 2 : mem read to dst
   -- bit 1 : mem write
   -- bit 0 : reg write
   signal microcode_value : std_logic_vector(6 downto 0);

   signal opcode   : std_logic_vector(3 downto 0);
   signal src_mode : std_logic_vector(1 downto 0);
   signal dst_mode : std_logic_vector(1 downto 0);

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

   opcode   <= fetch_data(R_OPCODE);
   src_mode <= fetch_data(R_SRC_MODE);
   dst_mode <= fetch_data(R_DST_MODE);

   -- Special case when src = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".

   immediate <= '1' when fetch_data(R_SRC_REG) = "1111" and fetch_data(R_SRC_MODE) = C_MODE_INC
           else '0';

   reg_src_addr_o <= fetch_data(R_SRC_REG);
   reg_dst_addr_o <= fetch_data(R_DST_REG);

   fetch_ready_o <= exe_ready_i when count = 0
               else '0';

   -- bit  5   : read from dst
   -- bit  4   : write to dst
   -- bit  3   : src mem
   -- bit  2   : dst mem
   -- bits 1-0 : count
   microcode_addr(5) <= '0' when opcode = C_OPCODE_MOVE or
                                 opcode = C_OPCODE_SWAP or
                                 opcode = C_OPCODE_NOT
                   else '1';
   microcode_addr(4) <= '0' when opcode = C_OPCODE_CMP
                   else '1';
   microcode_addr(3) <= '0' when src_mode = C_MODE_REG
                   else '1';
   microcode_addr(2) <= '0' when dst_mode = C_MODE_REG
                   else '1';
   microcode_addr(1 downto 0) <= count;

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

         fetch_valid_o <= '0';
         fetch_addr_o  <= (others => '0');

         if count > 0 or (fetch_valid_i = '1' and fetch_ready_o = '1') then
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

            if microcode_value(C_LAST) = '1' then
               count <= "00";
            else
               count <= count + 1;
            end if;
         end if;

         if rst_i = '1' then
            fetch_valid_o  <= '1';
            fetch_addr_o   <= (others => '0');
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

