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
      wb_cyc_o     : out std_logic := '0';
      wb_stb_o     : out std_logic := '0';
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

   signal osf_mem_valid : std_logic;
   signal osf_mem_ready : std_logic;
   signal osf_mem_data  : std_logic;

   signal osf_src_ready : std_logic;
   signal osf_dst_ready : std_logic;

begin

   s_ready_o <= osf_mem_ready and not wb_stall_i;

   p_memory : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if wb_stall_i = '0' then
            -- Reqeust is accepted
            wb_stb_o  <= '0';
            wb_we_o   <= '0';
         end if;

         if wb_ack_i = '1' then
            -- Response is received
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
         end if;

         if s_valid_i = '1' and s_ready_o = '1' then
            if s_op_i(C_READ_SRC) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= s_addr_i;
               wb_we_o   <= '0';
            end if;

            if s_op_i(C_READ_DST) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= s_addr_i;
               wb_we_o   <= '0';
            end if;

            if s_op_i(C_WRITE) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= s_addr_i;
               wb_we_o   <= '1';
               wb_dat_o  <= s_data_i;
            end if;
         end if;

         if rst_i = '1' then
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
         end if;
      end if;
   end process p_memory;


   ----------------------
   -- Store the request
   ----------------------

   i_one_stage_fifo_mem : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 1
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         s_valid_i   => s_valid_i and s_ready_o and (s_op_i(C_READ_SRC) or s_op_i(C_READ_DST)),
         s_ready_o   => osf_mem_ready,
         s_data_i(0) => s_op_i(C_READ_SRC),
         m_valid_o   => osf_mem_valid,
         m_ready_i   => wb_ack_i,
         m_data_o(0) => osf_mem_data
      ); -- i_one_stage_fifo_mem


   ------------------------------------------
   -- Store the response for the SRC output
   ------------------------------------------

   i_one_stage_fifo_src : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => wb_ack_i and osf_mem_valid and osf_mem_data,
         s_ready_o => osf_src_ready,
         s_data_i  => wb_data_i,
         m_valid_o => msrc_valid_o,
         m_ready_i => msrc_ready_i,
         m_data_o  => msrc_data_o
      ); -- i_one_stage_fifo_src


   ------------------------------------------
   -- Store the response for the DST output
   ------------------------------------------

   i_one_stage_fifo_dst : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => wb_ack_i and osf_mem_valid and not osf_mem_data,
         s_ready_o => osf_dst_ready,
         s_data_i  => wb_data_i,
         m_valid_o => mdst_valid_o,
         m_ready_i => mdst_ready_i,
         m_data_o  => mdst_data_o
      ); -- i_one_stage_fifo_dst

end architecture synthesis;

