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

   signal fetch2dect_valid    : std_logic;
   signal fetch2dect_ready    : std_logic;
   signal fetch2dect_addr     : std_logic_vector(15 downto 0);
   signal fetch2dect_data     : std_logic_vector(15 downto 0);

   signal fetch2decp_valid    : std_logic;
   signal fetch2decp_ready    : std_logic;
   signal fetch2decp_addr     : std_logic_vector(15 downto 0);
   signal fetch2decp_data     : std_logic_vector(15 downto 0);

   -- Decode to Register file
   signal dec2reg_src_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_src_val     : std_logic_vector(15 downto 0);
   signal dec2reg_dst_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_dst_val     : std_logic_vector(15 downto 0);
   signal dec2reg_flags       : std_logic_vector(15 downto 0);

   -- Decode to execute
   signal dec2exe_valid       : std_logic;
   signal dec2exe_ready       : std_logic;
   signal dec2exe_microop     : std_logic_vector(5 downto 0);
   signal dec2exe_opcode      : std_logic_vector(3 downto 0);
   signal dec2exe_flags       : std_logic_vector(15 downto 0);
   signal dec2exe_flags_we    : std_logic;
   signal dec2exe_src_val     : std_logic_vector(15 downto 0);
   signal dec2exe_dst_val     : std_logic_vector(15 downto 0);
   signal dec2exe_reg_addr    : std_logic_vector(3 downto 0);
   signal dec2exe_mem_addr    : std_logic_vector(15 downto 0);

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
   signal exe2reg_flags_we    : std_logic;
   signal exe2reg_flags       : std_logic_vector(15 downto 0);
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
         G_PAUSE_SIZE => -8
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


   -- Inserted for better timing
   i_one_stage_fifo : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 32
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => fetch2decp_valid,
         s_ready_o => fetch2decp_ready,
         s_data_i(31 downto 16) => fetch2decp_addr,
         s_data_i(15 downto 0)  => fetch2decp_data,
         m_valid_o => fetch2dect_valid,
         m_ready_i => fetch2dect_ready,
         m_data_o(31 downto 16) => fetch2dect_addr,
         m_data_o(15 downto 0)  => fetch2dect_data
      ); -- i_one_stage_fifo


   i_decode : entity work.decode
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         fetch_valid_i   => fetch2dect_valid,
         fetch_ready_o   => fetch2dect_ready,
         fetch_addr_i    => fetch2dect_addr,
         fetch_data_i    => fetch2dect_data,
         reg_src_addr_o  => dec2reg_src_reg,
         reg_src_val_i   => dec2reg_src_val,
         reg_dst_addr_o  => dec2reg_dst_reg,
         reg_dst_val_i   => dec2reg_dst_val,
         reg_flags_i     => dec2reg_flags,
         exe_valid_o     => dec2exe_valid,
         exe_ready_i     => dec2exe_ready,
         exe_microop_o   => dec2exe_microop,
         exe_opcode_o    => dec2exe_opcode,
         exe_flags_o     => dec2exe_flags,
         exe_flags_we_o  => dec2exe_flags_we,
         exe_src_val_o   => dec2exe_src_val,
         exe_dst_val_o   => dec2exe_dst_val,
         exe_reg_addr_o  => dec2exe_reg_addr,
         exe_mem_addr_o  => dec2exe_mem_addr
      ); -- i_decode


   i_registers : entity work.registers
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         src_reg_i     => dec2reg_src_reg,
         src_val_o     => dec2reg_src_val,
         dst_reg_i     => dec2reg_dst_reg,
         dst_val_o     => dec2reg_dst_val,
         flags_o       => dec2reg_flags,
         flags_we_i    => exe2reg_flags_we,
         flags_i       => exe2reg_flags,
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
         dec_flags_i     => dec2exe_flags,
         dec_flags_we_i  => dec2exe_flags_we,
         dec_src_val_i   => dec2exe_src_val,
         dec_dst_val_i   => dec2exe_dst_val,
         dec_reg_addr_i  => dec2exe_reg_addr,
         dec_mem_addr_i  => dec2exe_mem_addr,
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
         reg_flags_we_o  => exe2reg_flags_we,
         reg_flags_o     => exe2reg_flags,
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
         if wbd_stb_o = '1' and wbd_we_o = '1' and wbd_stall_i = '0' then
            report "MEMORY   WRITE value : " & to_hstring(wbd_dat_o) & " to address " & to_hstring(wbd_addr_o);
         end if;

         if exe2reg_we = '1' then
            report "REGISTER WRITE value : " & to_hstring(exe2reg_val) & " to register " & to_hstring(exe2reg_addr);
         end if;
      end if;
   end process p_debug;

end architecture synthesis;


