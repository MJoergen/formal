library ieee;
use ieee.std_logic_1164.all;

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

      -- Instruction fetch
      fetch_valid_o   : out std_logic;
      fetch_addr_o    : out std_logic_vector(15 downto 0);
      fetch_valid_i   : in  std_logic;
      fetch_ready_o   : out std_logic;
      fetch_addr_i    : in  std_logic_vector(15 downto 0);
      fetch_data_i    : in  std_logic_vector(15 downto 0);

      -- Register file
      reg_src_addr_o  : out std_logic_vector(3 downto 0);
      reg_dst_addr_o  : out std_logic_vector(3 downto 0);
      reg_src_val_i   : in  std_logic_vector(15 downto 0);
      reg_dst_val_i   : in  std_logic_vector(15 downto 0);

      -- Execute stage
      exe_valid_o     : out std_logic;
      exe_ready_i     : in  std_logic;
      exe_microop_o   : out std_logic_vector(1 downto 0);
      exe_opcode_o    : out std_logic_vector(3 downto 0);
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

   constant C_MICRO_MEM_READ_SRC : std_logic_vector(1 downto 0) := "00";
   constant C_MICRO_MEM_READ_DST : std_logic_vector(1 downto 0) := "01";
   constant C_MICRO_MEM_WRITE    : std_logic_vector(1 downto 0) := "10";
   constant C_MICRO_REG_WRITE    : std_logic_vector(1 downto 0) := "11";

   constant C_MODE_REG : std_logic_vector(1 downto 0) := "00"; -- R
   constant C_MODE_MEM : std_logic_vector(1 downto 0) := "01"; -- @R
   constant C_MODE_INC : std_logic_vector(1 downto 0) := "10"; -- @R++
   constant C_MODE_DEC : std_logic_vector(1 downto 0) := "11"; -- @--R

   signal immediate : std_logic;

begin

   -- Special case when src = @R15++, i.e. 11-8 = "1111" and 7-6 = "10".

   immediate <= '1' when fetch_data_i(R_SRC_REG) = "1111" and fetch_data_i(R_SRC_MODE) = C_MODE_INC
           else '0';

   exe_opcode_o   <= fetch_data_i(R_OPCODE);
   reg_src_addr_o <= fetch_data_i(R_SRC_REG);
   reg_dst_addr_o <= fetch_data_i(R_DST_REG);

   exe_src_val_o  <= reg_src_val_i;
   exe_dst_val_o  <= reg_dst_val_i;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fetch_valid_o <= '0';
         fetch_addr_o  <= (others => '0');
         if rst_i = '1' then
            fetch_valid_o <= '1';
            fetch_addr_o  <= (others => '0');
         end if;
      end if;
   end process p_fsm;

end architecture synthesis;

--              MICROOP      OPCODE  REG_ADDR  MEM_ADDR
-- MOVE R0,R1   REG_WRITE     MOVE    1          --
-- MOVE R0,@R1  MEM_WRITE     MOVE    --         R1
-- MOVE @R0,R1  MEM_READ_SRC  --      --         R0
--              REG_WRITE     MOVE    1          --
-- MOVE @R0,@R1 MEM_READ_SRC  --      --         R0
--              MEM_WRITE     MOVE    --         R1
--
-- ADD  R0,R1   REG_WRITE     ADD     1          --
-- ADD  R0,@R1  MEM_WRITE     ADD     --         R1
-- ADD  @R0,R1  MEM_READ_SRC  --      --         R0
--              REG_WRITE     ADD     1          --
-- ADD  @R0,@R1 MEM_READ_SRC  --      --         R0
--              MEM_READ_DST  --      --         R1
--              MEM_WRITE     ADD     --         R1

