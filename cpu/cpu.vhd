library ieee;
use ieee.std_logic_1164.all;

entity cpu is
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Instruction Memory
      wbi_cyc_o   : out std_logic;
      wbi_stb_o   : out std_logic;
      wbi_stall_i : in  std_logic;
      wbi_addr_o  : out std_logic_vector(15 downto 0);
      wbi_ack_i   : in  std_logic;
      wbi_data_i  : in  std_logic_vector(15 downto 0);

      -- Data Memory
      wbd_cyc_o   : out std_logic;
      wbd_stb_o   : out std_logic;
      wbd_stall_i : in  std_logic;
      wbd_addr_o  : out std_logic_vector(15 downto 0);
      wbd_we_o    : out std_logic;
      wbd_dat_o   : out std_logic_vector(15 downto 0);
      wbd_ack_i   : in  std_logic;
      wbd_data_i  : in  std_logic_vector(15 downto 0)
   );
end entity cpu;

architecture synthesis of cpu is

   -- Fetch to decode
   signal fetch2dec_valid     : std_logic;
   signal fetch2dec_ready     : std_logic;
   signal fetch2dec_addr      : std_logic_vector(15 downto 0);
   signal fetch2dec_data      : std_logic_vector(15 downto 0);

   signal fetch2decp_valid    : std_logic;
   signal fetch2decp_ready    : std_logic;
   signal fetch2decp_addr     : std_logic_vector(15 downto 0);
   signal fetch2decp_data     : std_logic_vector(15 downto 0);

   -- Decode to Register file
   signal dec2reg_src_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_src_val     : std_logic_vector(15 downto 0);
   signal dec2reg_dst_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_dst_val     : std_logic_vector(15 downto 0);
   signal reg2dec_r14         : std_logic_vector(15 downto 0);

   -- Decode to execute
   signal dec2exe_valid       : std_logic;
   signal dec2exe_ready       : std_logic;
   signal dec2exe_microop     : std_logic_vector(7 downto 0);
   signal dec2exe_opcode      : std_logic_vector(3 downto 0);
   signal dec2exe_jmp_mode    : std_logic_vector(1 downto 0);
   signal dec2exe_jmp_cond    : std_logic_vector(2 downto 0);
   signal dec2exe_jmp_neg     : std_logic;
   signal dec2exe_ctrl        : std_logic_vector(5 downto 0);
   signal dec2exe_r14         : std_logic_vector(15 downto 0);
   signal dec2exe_r14_we      : std_logic;
   signal dec2exe_src_addr    : std_logic_vector(3 downto 0);
   signal dec2exe_src_val     : std_logic_vector(15 downto 0);
   signal dec2exe_src_mode    : std_logic_vector(1 downto 0);
   signal dec2exe_dst_addr    : std_logic_vector(3 downto 0);
   signal dec2exe_dst_val     : std_logic_vector(15 downto 0);
   signal dec2exe_dst_mode    : std_logic_vector(1 downto 0);
   signal dec2exe_reg_addr    : std_logic_vector(3 downto 0);

   -- Execute to memory
   signal exe2mem_valid       : std_logic;
   signal exe2mem_ready       : std_logic;
   signal exe2mem_op          : std_logic_vector(2 downto 0);
   signal exe2mem_addr        : std_logic_vector(15 downto 0);
   signal exe2mem_wr_data     : std_logic_vector(15 downto 0);

   -- Memory to execute
   signal mem2exe_src_valid   : std_logic;
   signal mem2exe_src_ready   : std_logic;
   signal mem2exe_src_data    : std_logic_vector(15 downto 0);
   signal mem2exe_dst_valid   : std_logic;
   signal mem2exe_dst_ready   : std_logic;
   signal mem2exe_dst_data    : std_logic_vector(15 downto 0);

   -- Execute to registers
   signal exe2reg_r14_we      : std_logic;
   signal exe2reg_r14         : std_logic_vector(15 downto 0);
   signal exe2reg_we          : std_logic;
   signal exe2reg_addr        : std_logic_vector(3 downto 0);
   signal exe2reg_val         : std_logic_vector(15 downto 0);

   -- Execute to fetch
   signal exe2fetch_valid     : std_logic;
   signal exe2fetch_addr      : std_logic_vector(15 downto 0);

begin

   i_fetch : entity work.fetch
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         wb_cyc_o   => wbi_cyc_o,
         wb_stb_o   => wbi_stb_o,
         wb_stall_i => wbi_stall_i,
         wb_addr_o  => wbi_addr_o,
         wb_ack_i   => wbi_ack_i,
         wb_data_i  => wbi_data_i,
         dc_valid_o => fetch2dec_valid,
         dc_ready_i => fetch2dec_ready,
         dc_addr_o  => fetch2dec_addr,
         dc_data_o  => fetch2dec_data,
         dc_valid_i => exe2fetch_valid,
         dc_addr_i  => exe2fetch_addr
      ); -- i_fetch


   i_axi_pause : entity work.axi_pause
      generic map (
         G_TDATA_SIZE => 32,
         G_PAUSE_SIZE => 0
      )
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         s_tvalid_i => fetch2dec_valid,
         s_tready_o => fetch2dec_ready,
         s_tdata_i(31 downto 16)  => fetch2dec_addr,
         s_tdata_i(15 downto 0)   => fetch2dec_data,
         m_tvalid_o => fetch2decp_valid,
         m_tready_i => fetch2decp_ready,
         m_tdata_o(31 downto 16)  => fetch2decp_addr,
         m_tdata_o(15 downto 0)   => fetch2decp_data
      ); -- i_axi_pause


   i_decode : entity work.decode
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         fetch_valid_i   => fetch2decp_valid,
         fetch_ready_o   => fetch2decp_ready,
         fetch_addr_i    => fetch2decp_addr,
         fetch_data_i    => fetch2decp_data,
         reg_src_addr_o  => dec2reg_src_reg,
         reg_src_val_i   => dec2reg_src_val,
         reg_dst_addr_o  => dec2reg_dst_reg,
         reg_dst_val_i   => dec2reg_dst_val,
         reg_r14_i       => reg2dec_r14,
         exe_valid_o     => dec2exe_valid,
         exe_ready_i     => dec2exe_ready,
         exe_microop_o   => dec2exe_microop,
         exe_opcode_o    => dec2exe_opcode,
         exe_jmp_mode_o  => dec2exe_jmp_mode,
         exe_jmp_cond_o  => dec2exe_jmp_cond,
         exe_jmp_neg_o   => dec2exe_jmp_neg,
         exe_ctrl_o      => dec2exe_ctrl,
         exe_r14_o       => dec2exe_r14,
         exe_r14_we_o    => dec2exe_r14_we,
         exe_src_addr_o  => dec2exe_src_addr,
         exe_src_val_o   => dec2exe_src_val,
         exe_src_mode_o  => dec2exe_src_mode,
         exe_dst_addr_o  => dec2exe_dst_addr,
         exe_dst_val_o   => dec2exe_dst_val,
         exe_dst_mode_o  => dec2exe_dst_mode,
         exe_reg_addr_o  => dec2exe_reg_addr
      ); -- i_decode


   i_registers : entity work.registers
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         src_reg_i     => dec2reg_src_reg,
         src_val_o     => dec2reg_src_val,
         dst_reg_i     => dec2reg_dst_reg,
         dst_val_o     => dec2reg_dst_val,
         r14_o         => reg2dec_r14,
         r14_we_i      => exe2reg_r14_we,
         r14_i         => exe2reg_r14,
         reg_we_i      => exe2reg_we,
         reg_addr_i    => exe2reg_addr,
         reg_val_i     => exe2reg_val
      ); -- i_registers

   -- Writes to R15 are forwarded back to the fetch stage as well.
   exe2fetch_valid <= '1'             when rst_i else and(exe2reg_addr) and exe2reg_we;
   exe2fetch_addr  <= (others => '0') when rst_i else exe2reg_val;

   i_execute : entity work.execute
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         dec_valid_i     => dec2exe_valid,
         dec_ready_o     => dec2exe_ready,
         dec_microop_i   => dec2exe_microop,
         dec_opcode_i    => dec2exe_opcode,
         dec_jmp_mode_i  => dec2exe_jmp_mode,
         dec_jmp_cond_i  => dec2exe_jmp_cond,
         dec_jmp_neg_i   => dec2exe_jmp_neg,
         dec_ctrl_i      => dec2exe_ctrl,
         dec_r14_i       => dec2exe_r14,
         dec_r14_we_i    => dec2exe_r14_we,
         dec_src_addr_i  => dec2exe_src_addr,
         dec_src_val_i   => dec2exe_src_val,
         dec_src_mode_i  => dec2exe_src_mode,
         dec_dst_addr_i  => dec2exe_dst_addr,
         dec_dst_val_i   => dec2exe_dst_val,
         dec_dst_mode_i  => dec2exe_dst_mode,
         dec_reg_addr_i  => dec2exe_reg_addr,
         mem_valid_o     => exe2mem_valid,
         mem_ready_i     => exe2mem_ready,
         mem_op_o        => exe2mem_op,
         mem_addr_o      => exe2mem_addr,
         mem_wr_data_o   => exe2mem_wr_data,
         mem_src_valid_i => mem2exe_src_valid,
         mem_src_ready_o => mem2exe_src_ready,
         mem_src_data_i  => mem2exe_src_data,
         mem_dst_valid_i => mem2exe_dst_valid,
         mem_dst_ready_o => mem2exe_dst_ready,
         mem_dst_data_i  => mem2exe_dst_data,
         reg_r14_we_o    => exe2reg_r14_we,
         reg_r14_o       => exe2reg_r14,
         reg_we_o        => exe2reg_we,
         reg_addr_o      => exe2reg_addr,
         reg_val_o       => exe2reg_val
      ); -- i_execute


   i_memory : entity work.memory
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         s_valid_i       => exe2mem_valid,
         s_ready_o       => exe2mem_ready,
         s_op_i          => exe2mem_op,
         s_addr_i        => exe2mem_addr,
         s_data_i        => exe2mem_wr_data,
         msrc_valid_o    => mem2exe_src_valid,
         msrc_ready_i    => mem2exe_src_ready,
         msrc_data_o     => mem2exe_src_data,
         mdst_valid_o    => mem2exe_dst_valid,
         mdst_ready_i    => mem2exe_dst_ready,
         mdst_data_o     => mem2exe_dst_data,
         wb_cyc_o        => wbd_cyc_o,
         wb_stb_o        => wbd_stb_o,
         wb_stall_i      => wbd_stall_i,
         wb_addr_o       => wbd_addr_o,
         wb_we_o         => wbd_we_o,
         wb_dat_o        => wbd_dat_o,
         wb_ack_i        => wbd_ack_i,
         wb_data_i       => wbd_data_i
      ); -- i_memory

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if exe2reg_we = '1' then
            report "Write value 0x" & to_hstring(exe2reg_val) & " to register " & to_hstring(exe2reg_addr);
         end if;

         if wbd_stb_o = '1' and wbd_we_o = '1' and wbd_stall_i = '0' then
            report "Write value 0x" & to_hstring(wbd_dat_o) & " to memory 0x" & to_hstring(wbd_addr_o);
         end if;
      end if;
   end process p_debug;

end architecture synthesis;


