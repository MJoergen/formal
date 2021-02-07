library ieee;
use ieee.std_logic_1164.all;

entity system is
   port (
      clk_i  : in  std_logic;
      rstn_i : in  std_logic;
      led_o  : out std_logic_vector(15 downto 0)
   );
end entity system;

architecture synthesis of system is

   signal wbi_cyc     : std_logic;
   signal wbi_stb     : std_logic;
   signal wbi_stall   : std_logic;
   signal wbi_addr    : std_logic_vector(15 downto 0);
   signal wbi_ack     : std_logic;
   signal wbi_data_rd : std_logic_vector(15 downto 0);
   signal wbd_cyc     : std_logic;
   signal wbd_stb     : std_logic;
   signal wbd_stall   : std_logic;
   signal wbd_addr    : std_logic_vector(15 downto 0);
   signal wbd_we      : std_logic;
   signal wbd_data_wr : std_logic_vector(15 downto 0);
   signal wbd_ack     : std_logic;
   signal wbd_data_rd : std_logic_vector(15 downto 0);

begin

   led_o <= wbd_addr;

   i_cpu : entity work.cpu
      port map (
         clk_i       => clk_i,
         rst_i       => not rstn_i,
         wbi_cyc_o   => wbi_cyc,
         wbi_stb_o   => wbi_stb,
         wbi_stall_i => wbi_stall,
         wbi_addr_o  => wbi_addr,
         wbi_ack_i   => wbi_ack,
         wbi_data_i  => wbi_data_rd,
         wbd_cyc_o   => wbd_cyc,
         wbd_stb_o   => wbd_stb,
         wbd_stall_i => wbd_stall,
         wbd_addr_o  => wbd_addr,
         wbd_we_o    => wbd_we,
         wbd_dat_o   => wbd_data_wr,
         wbd_ack_i   => wbd_ack,
         wbd_data_i  => wbd_data_rd
      ); -- i_cpu

   i_tdp_mem : entity work.wb_tdp_mem
      generic map (
         G_INIT_FILE => "../cpu/prog.rom",
         G_RAM_STYLE => "block",
         G_ADDR_SIZE => 13,
         G_DATA_SIZE => 16
      )
      port map (
         clk_i        => clk_i,
         rst_i        => not rstn_i,
         wb_a_cyc_i   => wbi_cyc,
         wb_a_stb_i   => wbi_stb,
         wb_a_stall_o => wbi_stall,
         wb_a_addr_i  => wbi_addr(12 downto 0),
         wb_a_we_i    => '0',
         wb_a_data_i  => X"0000",
         wb_a_ack_o   => wbi_ack,
         wb_a_data_o  => wbi_data_rd,
         wb_b_cyc_i   => wbd_cyc,
         wb_b_stb_i   => wbd_stb,
         wb_b_stall_o => wbd_stall,
         wb_b_addr_i  => wbd_addr(12 downto 0),
         wb_b_we_i    => wbd_we,
         wb_b_data_i  => wbd_data_wr,
         wb_b_ack_o   => wbd_ack,
         wb_b_data_o  => wbd_data_rd
      ); -- i_tdp_mem

end architecture synthesis;

