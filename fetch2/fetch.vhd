library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- A simple instruction fetch unit.
-- This unit has four interfaces:
-- 1. Sending read requests to WISHBONE (with possible backpressure)
-- 2. Receiving read responses from WISHBONE
-- 3. Sending instructions to DECODE stage (with possible backpressure)
-- 4. Receiving a new PC from DECODE

-- The wishbone interface is running in pipeline mode. This means the STB
-- signal is asserted for one clock cycle (or until STALL is low) for each
-- request, whereas the CYC signal is held high until the corresponding ACKs
-- are received.  In this implementation, up to two outstanding wishbone
-- request are used.

entity fetch is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Send read request to WISHBONE
      wb_cyc_o   : out std_logic := '0';
      wb_stb_o   : out std_logic := '0';
      wb_stall_i : in  std_logic;
      wb_addr_o  : out std_logic_vector(15 downto 0);

      -- Receive read response from WISHBONE
      wb_ack_i   : in  std_logic;
      wb_data_i  : in  std_logic_vector(15 downto 0);

      -- Send instruction to DECODE
      dc_valid_o : out std_logic := '0';
      dc_ready_i : in  std_logic;
      dc_addr_o  : out std_logic_vector(15 downto 0);
      dc_data_o  : out std_logic_vector(15 downto 0);

      -- Receive a new PC from DECODE
      dc_valid_i : in  std_logic;
      dc_addr_i  : in  std_logic_vector(15 downto 0)
   );
end entity fetch;

architecture synthesis of fetch is

   signal tsf_in_addr_ready  : std_logic;
   signal tsf_in_addr_fill   : std_logic_vector(1 downto 0);
   signal tsf_out_addr_valid : std_logic;
   signal tsf_out_addr_ready : std_logic;
   signal tsf_out_addr_data  : std_logic_vector(15 downto 0);

   signal tsb_in_data_ready  : std_logic;
   signal tsb_in_data_fill   : std_logic_vector(1 downto 0);
   signal tsb_out_data_valid : std_logic;
   signal tsb_out_data_ready : std_logic;
   signal tsb_out_data_data  : std_logic_vector(15 downto 0);

begin

   -- Control the wishbone request interface
   p_wishbone : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Clear request when it has been accepted
         if not wb_stall_i then
            wb_stb_o <= '0';
         end if;

         -- Increment address when request has been accepted
         if wb_cyc_o and wb_stb_o and not wb_stall_i then
            wb_addr_o <= wb_addr_o + 1;
         end if;

         -- Clear transaction when no requests active
         if tsf_in_addr_fill = "00" then
            wb_cyc_o <= '0';
         end if;

         -- Abort current wishbone transaction
         if dc_valid_i = '1' then
            wb_addr_o <= dc_addr_i;
            wb_cyc_o <= '0';
            wb_stb_o <= '0';
         end if;

         -- Start new transaction when ready to receive response
         if (tsf_out_addr_ready or nor(tsf_in_addr_fill)) and tsb_in_data_ready and not (wb_cyc_o and dc_valid_i) then
            wb_cyc_o <= '1';
            wb_stb_o <= '1';
         end if;

         if rst_i = '1' then
            wb_cyc_o <= '0';
            wb_stb_o <= '0';
         end if;
      end if;
   end process p_wishbone;


   -- FIFO to store the WISHBONE address
   i_two_stage_fifo_addr : entity work.two_stage_fifo
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i or dc_valid_i,
         s_valid_i => wb_cyc_o and wb_stb_o and not wb_stall_i,
         s_ready_o => tsf_in_addr_ready,
         s_data_i  => wb_addr_o,
         s_fill_o  => tsf_in_addr_fill,
         m_valid_o => tsf_out_addr_valid,
         m_ready_i => tsf_out_addr_ready,
         m_data_o  => tsf_out_addr_data
      ); -- i_two_stage_fifo_addr


   -- FIFO to store the WISHBONE data
   i_two_stage_buffer_data : entity work.two_stage_buffer
      generic map (
         G_DATA_SIZE => 16
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i or dc_valid_i,
         s_valid_i => wb_cyc_o and wb_ack_i,
         s_ready_o => tsb_in_data_ready,
         s_data_i  => wb_data_i,
         s_fill_o  => tsb_in_data_fill,
         m_valid_o => tsb_out_data_valid,
         m_ready_i => tsb_out_data_ready,
         m_data_o  => tsb_out_data_data
      ); -- i_two_stage_buffer_data


   -- Concatenate WISHBONE address and data
   i_pipe_concat : entity work.pipe_concat
      generic map (
         G_DATA0_SIZE => 16,
         G_DATA1_SIZE => 16
      )
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i or dc_valid_i,
         s1_valid_i => tsf_out_addr_valid,
         s1_ready_o => tsf_out_addr_ready,
         s1_data_i  => tsf_out_addr_data,
         s0_valid_i => tsb_out_data_valid,
         s0_ready_o => tsb_out_data_ready,
         s0_data_i  => tsb_out_data_data,
         m_valid_o  => dc_valid_o,
         m_ready_i  => dc_ready_i,
         m_data_o(31 downto 16) => dc_addr_o,
         m_data_o(15 downto 0)  => dc_data_o
      ); -- i_pipe_concat

end architecture synthesis;

