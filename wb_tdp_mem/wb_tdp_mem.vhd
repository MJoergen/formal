library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- A True Dual Port memory with two Wishbone Slave interfaces.

entity wb_tdp_mem is
   generic (
      G_INIT_FILE : string := "";
      G_RAM_STYLE : string := "block";
      G_ADDR_SIZE : integer := 8;
      G_DATA_SIZE : integer := 8
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      -- Port A
      wb_a_cyc_i   : in  std_logic;
      wb_a_stall_o : out std_logic;
      wb_a_stb_i   : in  std_logic;
      wb_a_ack_o   : out std_logic;
      wb_a_we_i    : in  std_logic;
      wb_a_addr_i  : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wb_a_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      wb_a_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      -- Port B
      wb_b_cyc_i   : in  std_logic;
      wb_b_stall_o : out std_logic;
      wb_b_stb_i   : in  std_logic;
      wb_b_ack_o   : out std_logic;
      wb_b_we_i    : in  std_logic;
      wb_b_addr_i  : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wb_b_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      wb_b_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity wb_tdp_mem;

architecture synthesis of wb_tdp_mem is

   -- Port A
   signal a_addr    : std_logic_vector(G_ADDR_SIZE-1 downto 0);
   signal a_wr_en   : std_logic;
   signal a_wr_data : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal a_rd_en   : std_logic;
   signal a_rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal wb_a_ack  : std_logic;

   -- Port B
   signal b_addr    : std_logic_vector(G_ADDR_SIZE-1 downto 0);
   signal b_wr_en   : std_logic;
   signal b_wr_data : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal b_rd_en   : std_logic;
   signal b_rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal wb_b_ack  : std_logic;

begin

   i_tdp_ram : entity work.tdp_ram
      generic map (
         G_INIT_FILE => G_INIT_FILE,
         G_RAM_STYLE => G_RAM_STYLE,
         G_ADDR_SIZE => G_ADDR_SIZE,
         G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         a_addr_i    => a_addr,
         a_wr_en_i   => a_wr_en,
         a_wr_data_i => a_wr_data,
         a_rd_en_i   => a_rd_en,
         a_rd_data_o => a_rd_data,
         b_addr_i    => b_addr,
         b_wr_en_i   => b_wr_en,
         b_wr_data_i => b_wr_data,
         b_rd_en_i   => b_rd_en,
         b_rd_data_o => b_rd_data
      ); -- i_tdp_ram


   -- Acknowledge
   p_ack : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wb_a_ack <= wb_a_cyc_i and wb_a_stb_i and not wb_a_stall_o;
         wb_b_ack <= wb_b_cyc_i and wb_b_stb_i and not wb_b_stall_o;

         if rst_i = '1' then
            wb_a_ack <= '0';
            wb_b_ack <= '0';
         end if;
      end if;
   end process p_ack;


   a_wr_en      <= wb_a_cyc_i and wb_a_stb_i and wb_a_we_i and not wb_a_stall_o;
   a_rd_en      <= wb_a_cyc_i and wb_a_stb_i and (not wb_a_we_i) and not wb_a_stall_o;
   a_wr_data    <= wb_a_data_i;
   a_addr       <= wb_a_addr_i;
   wb_a_data_o  <= a_rd_data;
   wb_a_stall_o <= '0';
   wb_a_ack_o   <= wb_a_ack;

   b_wr_en      <= wb_b_cyc_i and wb_b_stb_i and wb_b_we_i and not wb_b_stall_o;
   b_rd_en      <= wb_b_cyc_i and wb_b_stb_i and (not wb_b_we_i) and not wb_b_stall_o;
   b_wr_data    <= wb_b_data_i;
   b_addr       <= wb_b_addr_i;
   wb_b_data_o  <= b_rd_data;
   wb_b_stall_o <= '0';
   wb_b_ack_o   <= wb_b_ack;

end architecture synthesis;

