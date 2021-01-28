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

entity execute is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From decode
      dec_valid_i     : in  std_logic;
      dec_ready_o     : out std_logic;
      dec_microop_i   : in  std_logic_vector(5 downto 0);
      dec_opcode_i    : in  std_logic_vector(3 downto 0);
      dec_flags_i     : in  std_logic_vector(15 downto 0);
      dec_src_val_i   : in  std_logic_vector(15 downto 0);
      dec_dst_val_i   : in  std_logic_vector(15 downto 0);
      dec_reg_addr_i  : in  std_logic_vector(3 downto 0);
      dec_mem_addr_i  : in  std_logic_vector(15 downto 0);

      -- Memory
      wb_cyc_o        : out std_logic;
      wb_stb_o        : out std_logic;
      wb_stall_i      : in  std_logic;
      wb_addr_o       : out std_logic_vector(15 downto 0);
      wb_we_o         : out std_logic;
      wb_dat_o        : out std_logic_vector(15 downto 0);
      wb_ack_i        : in  std_logic;
      wb_data_i       : in  std_logic_vector(15 downto 0);

      -- Register file
      reg_flags_we_o  : out std_logic;
      reg_flags_o     : out std_logic_vector(15 downto 0);
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

   -- ALU
   signal alu_oper      : std_logic_vector(3 downto 0);
   signal alu_flags     : std_logic_vector(15 downto 0);
   signal alu_src_val   : std_logic_vector(15 downto 0);
   signal alu_dst_val   : std_logic_vector(15 downto 0);
   signal alu_res_val   : std_logic_vector(15 downto 0);
   signal alu_res_flags : std_logic_vector(15 downto 0);

   signal mem_ready     : std_logic;
   signal mem_src_valid : std_logic;
   signal mem_src_ready : std_logic;
   signal mem_src_data  : std_logic_vector(15 downto 0);
   signal mem_dst_valid : std_logic;
   signal mem_dst_ready : std_logic;
   signal mem_dst_data  : std_logic_vector(15 downto 0);

   signal wait_for_mem_access : std_logic;
   signal wait_for_mem_src    : std_logic;
   signal wait_for_mem_dst    : std_logic;

begin

   wait_for_mem_src    <= dec_valid_i and dec_microop_i(C_MEM_ALU_SRC) and not mem_src_valid;
   wait_for_mem_dst    <= dec_valid_i and dec_microop_i(C_MEM_ALU_DST) and not mem_dst_valid;
   wait_for_mem_access <= dec_valid_i and (dec_microop_i(C_MEM_ALU_DST) or
                                           dec_microop_i(C_MEM_READ_SRC) or
                                           dec_microop_i(C_MEM_READ_DST)) and not mem_ready;

   alu_oper       <= dec_opcode_i;
   alu_flags      <= dec_flags_i;

   alu_src_val    <= mem_src_data when dec_microop_i(C_MEM_ALU_SRC) = '1' else dec_src_val_i;
   alu_dst_val    <= mem_dst_data when dec_microop_i(C_MEM_ALU_DST) = '1' else dec_dst_val_i;

   dec_ready_o    <= not (wait_for_mem_src or wait_for_mem_dst or wait_for_mem_access);

   mem_src_ready  <= dec_microop_i(C_MEM_ALU_SRC);
   mem_dst_ready  <= dec_microop_i(C_MEM_ALU_DST);

   reg_flags_o    <= alu_res_flags;

   p_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         reg_we_o       <= '0';
         reg_addr_o     <= (others => '0');
         reg_val_o      <= (others => '0');
         reg_flags_we_o <= '0';

         if dec_valid_i = '1' and dec_ready_o = '1' then
            if dec_microop_i(C_REG_WRITE) = '1' then
               reg_flags_we_o <= '1';
               reg_we_o   <= '1';
               reg_addr_o <= dec_reg_addr_i;
               reg_val_o  <= alu_res_val;
            end if;
         end if;
      end if;
   end process p_reg;

   i_alu : entity work.alu
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         opcode_i    => alu_oper,
         sr_i        => alu_flags,
         src_data_i  => alu_src_val,
         dst_data_i  => alu_dst_val,
         res_data_o  => alu_res_val,
         sr_o        => alu_res_flags
      ); -- i_alu

   i_memory : entity work.memory
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         dec_valid_i     => dec_valid_i and not (wait_for_mem_src or wait_for_mem_dst),
         dec_ready_o     => mem_ready,
         dec_microop_i   => dec_microop_i,
         dec_mem_addr_i  => dec_mem_addr_i,
         alu_res_val_i   => alu_res_val,
         mem_src_valid_o => mem_src_valid,
         mem_src_ready_i => mem_src_ready,
         mem_src_data_o  => mem_src_data,
         mem_dst_valid_o => mem_dst_valid,
         mem_dst_ready_i => mem_dst_ready,
         mem_dst_data_o  => mem_dst_data,
         wb_cyc_o        => wb_cyc_o,
         wb_stb_o        => wb_stb_o,
         wb_stall_i      => wb_stall_i,
         wb_addr_o       => wb_addr_o,
         wb_we_o         => wb_we_o,
         wb_dat_o        => wb_dat_o,
         wb_ack_i        => wb_ack_i,
         wb_data_i       => wb_data_i
      ); -- i_memory

end architecture synthesis;

