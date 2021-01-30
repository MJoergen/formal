library ieee;
use ieee.std_logic_1164.all;

entity memory is
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      -- From execute
      s_valid_i    : in  std_logic;
      s_ready_o    : out std_logic;
      s_op_i       : in  std_logic_vector(2 downto 0);
      s_addr_i     : in  std_logic_vector(15 downto 0);
      s_data_i     : in  std_logic_vector(15 downto 0);

      -- To execute
      msrc_valid_o : out std_logic;
      msrc_ready_i : in  std_logic;
      msrc_data_o  : out std_logic_vector(15 downto 0);

      mdst_valid_o : out std_logic;
      mdst_ready_i : in  std_logic;
      mdst_data_o  : out std_logic_vector(15 downto 0);

      -- Memory
      wb_cyc_o     : out std_logic;
      wb_stb_o     : out std_logic;
      wb_stall_i   : in  std_logic;
      wb_addr_o    : out std_logic_vector(15 downto 0);
      wb_we_o      : out std_logic;
      wb_dat_o     : out std_logic_vector(15 downto 0);
      wb_ack_i     : in  std_logic;
      wb_data_i    : in  std_logic_vector(15 downto 0)
   );
end entity memory;

architecture synthesis of memory is

   constant C_READ_SRC : integer := 2;
   constant C_READ_DST : integer := 1;
   constant C_WRITE    : integer := 0;

   signal osb_mem_in_valid  : std_logic;
   signal osb_mem_in_ready  : std_logic;
   signal osb_mem_out_valid : std_logic;
   signal osb_mem_out_ready : std_logic;
   signal osb_mem_data      : std_logic;

   signal osb_src_valid     : std_logic;
   signal osb_src_ready     : std_logic;
   signal osb_dst_valid     : std_logic;
   signal osb_dst_ready     : std_logic;

   signal wait_for_ack      : std_logic;

begin

   s_ready_o <= osb_mem_in_ready and not wb_stall_i and (wb_ack_i or not wait_for_ack) and osb_src_ready and osb_dst_ready and (msrc_ready_i or not msrc_valid_o) and (mdst_ready_i or not mdst_valid_o);

   -- WISHBONE request interface is combinatorial
   wb_cyc_o  <= ((s_valid_i and s_ready_o) or wait_for_ack) and not rst_i;
   wb_stb_o  <= wb_cyc_o and s_valid_i and s_ready_o;
   wb_addr_o <= s_addr_i;
   wb_we_o   <= s_op_i(C_WRITE);
   wb_dat_o  <= s_data_i;

   p_wait_for_ack : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wb_cyc_o and wb_ack_i then
            wait_for_ack <= '0';
         end if;

         if wb_cyc_o and wb_stb_o and not wb_stall_i then
            wait_for_ack <= '1';
         end if;

         if rst_i = '1' then
            wait_for_ack <= '0';
         end if;
      end if;
   end process p_wait_for_ack;


   ----------------------
   -- Store the request
   ----------------------

   osb_mem_in_valid <= s_valid_i and s_ready_o and (s_op_i(C_READ_SRC) or s_op_i(C_READ_DST));

   i_one_stage_buffer_mem : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => 1
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         s_valid_i   => osb_mem_in_valid,
         s_ready_o   => osb_mem_in_ready,
         s_data_i(0) => s_op_i(C_READ_SRC),
         m_valid_o   => osb_mem_out_valid,
         m_ready_i   => wb_ack_i,
         m_data_o(0) => osb_mem_data
      ); -- i_one_stage_buffer_mem

   osb_src_valid <= wb_ack_i and osb_mem_out_valid and osb_mem_data;
   osb_dst_valid <= wb_ack_i and osb_mem_out_valid and not osb_mem_data;

   ------------------------------------------
   -- Store the response for the SRC output
   ------------------------------------------

   i_one_stage_buffer_src : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => osb_src_valid,
         s_ready_o => osb_src_ready,
         s_data_i  => wb_data_i,
         m_valid_o => msrc_valid_o,
         m_ready_i => msrc_ready_i,
         m_data_o  => msrc_data_o
      ); -- i_one_stage_buffer_src


   ------------------------------------------
   -- Store the response for the DST output
   ------------------------------------------

   i_one_stage_buffer_dst : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => osb_dst_valid,
         s_ready_o => osb_dst_ready,
         s_data_i  => wb_data_i,
         m_valid_o => mdst_valid_o,
         m_ready_i => mdst_ready_i,
         m_data_o  => mdst_data_o
      ); -- i_one_stage_buffer_dst

end architecture synthesis;

