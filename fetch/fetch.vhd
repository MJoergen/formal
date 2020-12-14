library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A simple instruction fetch unit.
-- This unit has four interfaces:
-- 1. Sending read requests to WISHBONE (with possible backpressure)
-- 2. Receiving read responses from WISHBONE
-- 3. Sending instructions to DECODE stage (with possible backpressure)
-- 4. Receiving a new PC from DECODE

-- The wishbone interface is running in pipeline mode. This means the STB
-- signal is asserted for one clock cycle (or until STALL is low) for each
-- request, whereas the CYC signal is held high until the corresponding ACKs
-- are received.  In this implementation, only a single outstanding wishbone
-- request is used.

entity fetch is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Send read request to WISHBONE
      wb_cyc_o   : out std_logic;
      wb_stb_o   : out std_logic;
      wb_stall_i : in  std_logic;
      wb_addr_o  : out std_logic_vector(15 downto 0);

      -- Receive read response from WISHBONE
      wb_ack_i   : in  std_logic;
      wb_data_i  : in  std_logic_vector(15 downto 0);

      -- Send instruction to DECODE
      dc_valid_o : out std_logic;
      dc_ready_i : in  std_logic;
      dc_addr_o  : out std_logic_vector(15 downto 0);
      dc_inst_o  : out std_logic_vector(15 downto 0);

      -- Receive a new PC from DECODE
      dc_valid_i : in  std_logic;
      dc_pc_i    : in  std_logic_vector(15 downto 0)
   );
end entity fetch;

architecture synthesis of fetch is

   -- Registered output signals
   signal wb_cyc   : std_logic := '0';
   signal wb_stb   : std_logic := '0';
   signal wb_addr  : std_logic_vector(15 downto 0);
   signal dc_valid : std_logic := '0';
   signal dc_addr  : std_logic_vector(15 downto 0);
   signal dc_inst  : std_logic_vector(15 downto 0);

   -- Combinatorial signals
   signal wb_wait  : std_logic;
   signal dc_stall : std_logic;

begin

   wb_wait  <= wb_cyc and not wb_ack_i;
   dc_stall <= dc_valid and not dc_ready_i;

   -- Control the wishbone request interface
   p_wishbone : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Clear request when it has been accepted
         if wb_stall_i = '0' then
            wb_stb <= '0';
         end if;

         -- End cycle when response received
         if wb_ack_i = '1' then
            wb_cyc <= '0';
            wb_stb <= '0';
         end if;

         -- Increment address when response received and ready to issue new request
         if wb_wait = '0' and dc_stall = '0' then
            wb_addr <= std_logic_vector(unsigned(wb_addr) + 1);
            wb_cyc  <= '1';
            wb_stb  <= '1';
         end if;

         -- Abort current wishbone transaction
         if dc_valid_i = '1' then
            wb_addr <= dc_pc_i;
            wb_cyc <= '0';
            wb_stb <= '0';
         end if;

         -- If no current transaction start new one immediately
         if dc_valid_i = '1' and wb_cyc = '0' then
            wb_cyc <= '1';
            wb_stb <= '1';
         end if;

         if rst_i = '1' then
            wb_cyc <= '0';
            wb_stb <= '0';
         end if;
      end if;
   end process p_wishbone;


   -- Control the decode output signals
   p_decode : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Clear output when it has been accepted
         if dc_ready_i = '1' then
            dc_valid <= '0';
         end if;

         -- Output data received from wishbone
         if wb_cyc = '1' and wb_ack_i = '1' and dc_stall = '0' then
            dc_addr  <= wb_addr;
            dc_inst  <= wb_data_i;
            dc_valid <= '1';
         end if;

         if rst_i = '1' then
            dc_valid <= '0';
         end if;
      end if;
   end process p_decode;


   -- Connect output signals
   wb_cyc_o   <= wb_cyc;
   wb_stb_o   <= wb_stb;
   wb_addr_o  <= wb_addr;
   dc_valid_o <= dc_valid;
   dc_addr_o  <= dc_addr;
   dc_inst_o  <= dc_inst;

end architecture synthesis;

