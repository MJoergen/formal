library ieee;
use ieee.std_logic_1164.all;

entity memory is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From decode
      dec_valid_i     : in  std_logic;
      dec_ready_o     : out std_logic;
      dec_microop_i   : in  std_logic_vector(5 downto 0);
      dec_mem_addr_i  : in  std_logic_vector(15 downto 0);

      -- From alu
      alu_res_val_i   : in  std_logic_vector(15 downto 0);

      -- To execute
      mem_src_valid_o : out std_logic;
      mem_src_ready_i : in  std_logic;
      mem_src_data_o  : out std_logic_vector(15 downto 0);
      mem_dst_valid_o : out std_logic;
      mem_dst_ready_i : in  std_logic;
      mem_dst_data_o  : out std_logic_vector(15 downto 0);

      -- Memory
      wb_cyc_o        : out std_logic;
      wb_stb_o        : out std_logic;
      wb_stall_i      : in  std_logic;
      wb_addr_o       : out std_logic_vector(15 downto 0);
      wb_we_o         : out std_logic;
      wb_dat_o        : out std_logic_vector(15 downto 0);
      wb_ack_i        : in  std_logic;
      wb_data_i       : in  std_logic_vector(15 downto 0)
   );
end entity memory;

architecture synthesis of memory is

   constant C_MEM_ALU_SRC  : integer := 5;
   constant C_MEM_ALU_DST  : integer := 4;
   constant C_MEM_READ_SRC : integer := 3;
   constant C_MEM_READ_DST : integer := 2;
   constant C_MEM_WRITE    : integer := 1;
   constant C_REG_WRITE    : integer := 0;

   signal osf_mem_valid : std_logic;
   signal osf_mem_ready : std_logic;
   signal osf_mem_data  : std_logic;

   signal osf_src_ready : std_logic;
   signal osf_dst_ready : std_logic;

begin

   dec_ready_o <= osf_mem_ready and not wb_stall_i;

   p_memory : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wb_we_o   <= '0';
         wb_addr_o <= (others => '0');
         wb_dat_o  <= (others => '0');

         if wb_stall_i = '0' then
            wb_stb_o  <= '0';
         end if;

         if wb_ack_i = '1' then
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
         end if;

         if dec_valid_i = '1' and dec_ready_o = '1' then
            if dec_microop_i(C_MEM_READ_SRC) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= dec_mem_addr_i;
               wb_we_o   <= '0';
               wb_dat_o  <= (others => '0');
            end if;

            if dec_microop_i(C_MEM_READ_DST) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= dec_mem_addr_i;
               wb_we_o   <= '0';
               wb_dat_o  <= (others => '0');
            end if;

            if dec_microop_i(C_MEM_WRITE) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= dec_mem_addr_i;
               wb_we_o   <= '1';
               wb_dat_o  <= alu_res_val_i;
            end if;
         end if;

         if rst_i = '1' then
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
            wb_addr_o <= (others => '0');
            wb_we_o   <= '0';
            wb_dat_o  <= (others => '0');
         end if;
      end if;
   end process p_memory;


   i_one_stage_fifo_mem : entity work.one_stage_fifo
      generic map (
         G_DATA_SIZE => 1
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         s_valid_i   => dec_valid_i and dec_ready_o and (dec_microop_i(C_MEM_READ_SRC) or dec_microop_i(C_MEM_READ_DST)),
         s_ready_o   => osf_mem_ready,
         s_data_i(0) => dec_microop_i(C_MEM_READ_SRC),
         m_valid_o   => osf_mem_valid,
         m_ready_i   => wb_ack_i,
         m_data_o(0) => osf_mem_data
      ); -- i_one_stage_fifo_mem


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
         m_valid_o => mem_src_valid_o,
         m_ready_i => mem_src_ready_i,
         m_data_o  => mem_src_data_o
      ); -- i_one_stage_fifo_src


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
         m_valid_o => mem_dst_valid_o,
         m_ready_i => mem_dst_ready_i,
         m_data_o  => mem_dst_data_o
      ); -- i_one_stage_fifo_dst

end architecture synthesis;

