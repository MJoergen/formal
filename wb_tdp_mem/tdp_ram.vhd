library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity tdp_ram is
   generic (
      G_INIT_FILE : string := "";
      G_RAM_STYLE : string := "block";
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
   );
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      -- Port A
      a_addr_i      : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wr_en_i     : in  std_logic;
      a_wr_data_i   : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      a_rd_en_i     : in  std_logic;
      a_rd_data_o   : out std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');
      -- Port B
      b_addr_i      : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      b_wr_en_i     : in  std_logic;
      b_wr_data_i   : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      b_rd_en_i     : in  std_logic;
      b_rd_data_o   : out std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0')
   );
end entity tdp_ram;

architecture synthesis of tdp_ram is

   type ram_t is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return ram_t is
      FILE RamFile : text;
      variable RamFileLine : line;
      variable ram : ram_t := (others => (others => '0'));
   begin
      if RamFileName /= "" then
         file_open(RamFile, RamFileName, read_mode);
         for i in ram_t'range loop
            readline (RamFile, RamFileLine);
            read (RamFileLine, ram(i));
            if endfile(RamFile) then
               return ram;
            end if;
         end loop;
      end if;
      return ram;
   end function;

   -- Initial memory contents
   shared variable ram_r : ram_t := InitRamFromFile(G_INIT_FILE);

   attribute ram_style : string;
   attribute ram_style of ram_r : variable is G_RAM_STYLE;

begin

   p_a : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if a_rd_en_i = '1' then
            a_rd_data_o <= ram_r(to_integer(a_addr_i));
         end if;
         if a_wr_en_i = '1' then
            ram_r(to_integer(a_addr_i)) := a_wr_data_i;
         end if;
      end if;
   end process p_a;

   p_b : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if b_rd_en_i = '1' then
            b_rd_data_o <= ram_r(to_integer(b_addr_i));
         end if;
         if b_wr_en_i = '1' then
            ram_r(to_integer(b_addr_i)) := b_wr_data_i;
         end if;
      end if;
   end process p_b;

end architecture synthesis;

