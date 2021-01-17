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

   -- Decode to fetch
   signal dec2fetch_valid     : std_logic;
   signal dec2fetch_addr      : std_logic_vector(15 downto 0);

   -- Decode to Register file
   signal dec2reg_src_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_src_val     : std_logic_vector(15 downto 0);
   signal dec2reg_dst_reg     : std_logic_vector(3 downto 0);
   signal dec2reg_dst_val     : std_logic_vector(15 downto 0);
   signal dec2reg_flags       : std_logic_vector(15 downto 0);

   -- Decode to execute
   signal dec2exe_valid       : std_logic;
   signal dec2exe_ready       : std_logic;
   signal dec2exe_microop     : std_logic_vector(3 downto 0);
   signal dec2exe_opcode      : std_logic_vector(3 downto 0);
   signal dec2exe_flags       : std_logic_vector(15 downto 0);
   signal dec2exe_src_val     : std_logic_vector(15 downto 0);
   signal dec2exe_dst_val     : std_logic_vector(15 downto 0);
   signal dec2exe_reg_addr    : std_logic_vector(3 downto 0);
   signal dec2exe_mem_addr    : std_logic_vector(15 downto 0);

   -- ALU
   signal alu_oper            : std_logic_vector(3 downto 0);
   signal alu_flags           : std_logic_vector(15 downto 0);
   signal alu_src_val         : std_logic_vector(15 downto 0);
   signal alu_dst_val         : std_logic_vector(15 downto 0);
   signal alu_res_val         : std_logic_vector(15 downto 0);
   signal alu_res_flags       : std_logic_vector(15 downto 0);

   -- Execute to registers
   signal exe2reg_flags_we    : std_logic;
   signal exe2reg_flags       : std_logic_vector(15 downto 0);
   signal exe2reg_we          : std_logic;
   signal exe2reg_addr        : std_logic_vector(3 downto 0);
   signal exe2reg_val         : std_logic_vector(15 downto 0);

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
         dc_valid_i => dec2fetch_valid,
         dc_addr_i  => dec2fetch_addr
      ); -- i_fetch


   i_axi_pause : entity work.axi_pause
      generic map (
         G_TDATA_SIZE => 32,
         G_PAUSE_SIZE => -5
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
         fetch_valid_o   => dec2fetch_valid,
         fetch_addr_o    => dec2fetch_addr,
         fetch_valid_i   => fetch2decp_valid,
         fetch_ready_o   => fetch2decp_ready,
         fetch_addr_i    => fetch2decp_addr,
         fetch_data_i    => fetch2decp_data,
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


   i_execute : entity work.execute
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         dec_valid_i     => dec2exe_valid,
         dec_ready_o     => dec2exe_ready,
         dec_microop_i   => dec2exe_microop,
         dec_opcode_i    => dec2exe_opcode,
         reg_flags_i     => dec2exe_flags,
         reg_src_val_i   => dec2exe_src_val,
         reg_dst_val_i   => dec2exe_dst_val,
         reg_addr_i      => dec2exe_reg_addr,
         mem_addr_i      => dec2exe_mem_addr,
         alu_oper_o      => alu_oper,
         alu_flags_o     => alu_flags,
         alu_src_val_o   => alu_src_val,
         alu_dst_val_o   => alu_dst_val,
         alu_res_val_i   => alu_res_val,
         alu_res_flags_i => alu_res_flags,
         wb_cyc_o        => wbd_cyc_o,
         wb_stb_o        => wbd_stb_o,
         wb_stall_i      => wbd_stall_i,
         wb_addr_o       => wbd_addr_o,
         wb_we_o         => wbd_we_o,
         wb_dat_o        => wbd_dat_o,
         wb_ack_i        => wbd_ack_i,
         wb_data_i       => wbd_data_i,
         reg_flags_we_o  => exe2reg_flags_we,
         reg_flags_o     => exe2reg_flags,
         reg_we_o        => exe2reg_we,
         reg_addr_o      => exe2reg_addr,
         reg_val_o       => exe2reg_val
      ); -- i_execute

end architecture synthesis;


