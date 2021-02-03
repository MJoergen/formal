library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity dp_ram is
   generic (
      G_RAM_STYLE : string := "block";
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
   );
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      -- Write interface
      wr_addr_i     : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wr_data_i     : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      wr_en_i       : in  std_logic;
      -- Read interface
      rd_addr_i     : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      rd_data_o     : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity dp_ram;

architecture synthesis of dp_ram is

   type mem_t is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal ram_r : mem_t := (others => (others => '0'));

   attribute ram_style : string;
   attribute ram_style of ram_r : signal is G_RAM_STYLE;

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            ram_r(to_integer(wr_addr_i)) <= wr_data_i;
         end if;

-- pragma synthesis_off
         if rst_i = '1' then
            for i in 0 to 7 loop
               ram_r(i) <= X"111" * to_std_logic_vector(i, 4);
            end loop;
         end if;
-- pragma synthesis_on
      end if;
   end process p_write;


   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_data_o <= ram_r(to_integer(rd_addr_i));
      end if;
   end process p_read;

end architecture synthesis;

