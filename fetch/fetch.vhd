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
      dc_data_o  : out std_logic_vector(15 downto 0);

      -- Receive a new PC from DECODE
      dc_valid_i : in  std_logic;
      dc_addr_i  : in  std_logic_vector(15 downto 0)
   );
end entity fetch;

architecture synthesis of fetch is

   -- Registered output signals
   signal wb_cyc   : std_logic := '0';
   signal wb_stb   : std_logic := '0';
   signal wb_addr  : std_logic_vector(15 downto 0);
   signal dc_valid : std_logic := '0';
   signal dc_addr  : std_logic_vector(15 downto 0);
   signal dc_data  : std_logic_vector(15 downto 0);

   -- Combinatorial signals
   signal wb_wait  : std_logic;
   signal dc_stall : std_logic;

   -- Connected to one_stage_buffer
   signal osb_rst       : std_logic;
   signal osb_in_valid  : std_logic;
   signal osb_in_ready  : std_logic;
   signal osb_in_data   : std_logic_vector(31 downto 0);
   signal osb_out_valid : std_logic;
   signal osb_out_ready : std_logic;
   signal osb_out_data  : std_logic_vector(31 downto 0);

   subtype R_ADDR is natural range 31 downto 16;
   subtype R_DATA is natural range 15 downto  0;

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
         if wb_cyc = '1' and wb_ack_i = '1' then
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
            wb_addr <= dc_addr_i;
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
         if osb_in_ready = '1' or dc_valid_i = '1' then
            osb_in_valid <= '0';
         end if;

         -- Output data received from wishbone
         if wb_cyc = '1' and wb_ack_i = '1' and dc_valid_i = '0' then
            osb_in_data(R_ADDR) <= wb_addr;
            osb_in_data(R_DATA) <= wb_data_i;
            osb_in_valid <= '1';
         end if;

         if rst_i = '1' then
            osb_in_valid <= '0';
         end if;
      end if;
   end process p_decode;

   osb_rst <= rst_i or dc_valid_i;

   i_one_stage_buffer : entity work.one_stage_buffer
      generic map (
         G_DATA_SIZE => 32
      )
      port map (
         clk_i     => clk_i,
         rst_i     => osb_rst,
         s_valid_i => osb_in_valid,
         s_ready_o => osb_in_ready,
         s_data_i  => osb_in_data,
         m_valid_o => osb_out_valid,
         m_ready_i => osb_out_ready,
         m_data_o  => osb_out_data
      ); -- i_one_stage_buffer

   dc_addr  <= osb_out_data(R_ADDR);
   dc_data  <= osb_out_data(R_DATA);
   dc_valid <= osb_out_valid;
   osb_out_ready <= dc_ready_i;


   -- Connect output signals
   wb_cyc_o   <= wb_cyc;
   wb_stb_o   <= wb_stb;
   wb_addr_o  <= wb_addr;
   dc_valid_o <= dc_valid;
   dc_addr_o  <= dc_addr;
   dc_data_o  <= dc_data;

end architecture synthesis;

