library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A simple memory with a Wishbone Slave interface.
-- The requirements are as follows:
-- * When wb_ack_o is de-asserted, then wb_data_o is all zeros.
-- * The response always appears on the exact following clock cycle, i.e. a fixed latency of 1.
-- * We have no more than a single outstanding request at any given time.
-- * STB must be low when CYC is low.
-- * If CYC goes low mid-transaction, the transaction is aborted.
-- * While STB and STALL are active, the request cannot change.
-- * One request is made for every clock with STB and !STALL.
-- * One ACK response per request.
-- * No ACKs allowed when the bus is idle.
-- * No way to stall the ACK line.
-- * The bus result is in DATA when ACK is true.

entity wb_mem is
   generic (
      G_ADDR_SIZE : integer := 8;
      G_DATA_SIZE : integer := 16
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      wb_cyc_i   : in  std_logic;
      wb_stall_o : out std_logic;
      wb_stb_i   : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_we_i    : in  std_logic;
      wb_addr_i  : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wb_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      wb_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity wb_mem;

architecture synthesis of wb_mem is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- Initialize memory contents
   signal mem_r : mem_t := (others => (others => '0'));

   signal wb_stall_s : std_logic;
   signal wb_ack_r   : std_logic := '0';
   signal wb_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   wb_stall_s <= rst_i;

   -- Writing to memory
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wb_cyc_i = '1' and wb_stb_i = '1' and wb_stall_s = '0' and wb_we_i = '1' then
            mem_r(to_integer(unsigned(wb_addr_i))) <= wb_data_i;
         end if;
      end if;
   end process p_write;

   -- Reading from memory
   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wb_data_r <= (others => '0');
         wb_ack_r  <= '0';
         if wb_cyc_i = '1' and wb_stb_i = '1' and wb_stall_s = '0' then
            if wb_we_i = '0' then
               wb_data_r <= mem_r(to_integer(unsigned(wb_addr_i)));
            end if;
            wb_ack_r  <= '1'; -- This also ACK's the write transaction.
         end if;
      end if;
   end process p_read;

   -- Connect output signals
   wb_stall_o <= wb_stall_s;
   wb_ack_o   <= wb_ack_r;
   wb_data_o  <= wb_data_r;

end architecture synthesis;

