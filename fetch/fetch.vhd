library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A simple instruction fetch unit.
-- This unit essentially has four interfaces:
-- 1. Sending read requests to WISHBONE
-- 2. Receiving read responses from WISHBONE
-- 3. Sending instruction to DECODE stage
-- 4. Receiving a new PC from DECODE
-- Interfaces 1 and 3 support back-pressure, while interfaces 2 and 4 do not.

-- This first version is implemented using a state machine. This way we
-- can control when data is expected from the wishbone bus. However,
-- we must be ready to receive a new PC at any time.

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

   type state_t is (IDLE_ST, REQ_ST, WAIT_REQ_ST, WAIT_RESP_ST, WAIT_DECODE_ST);
   signal state : state_t := IDLE_ST;

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST => null;
               -- After reset, do nothing

            when REQ_ST =>
               -- After a new PC has been received, send request
               wb_cyc  <= '1';
               wb_stb  <= '1';
               state   <= WAIT_REQ_ST;

            when WAIT_REQ_ST =>
               -- Wait until WISHBONE has accepted request
               if wb_stall_i = '0' then
                  wb_stb <= '0';
                  state <= WAIT_RESP_ST;
               end if;

            when WAIT_RESP_ST =>
               -- Wait until WISHBONE has provided response
               if wb_ack_i = '1' then
                  dc_inst  <= wb_data_i;
                  dc_valid <= '1';
                  dc_addr  <= wb_addr;
                  wb_cyc   <= '0';
                  state    <= WAIT_DECODE_ST;
               end if;

            when WAIT_DECODE_ST =>
               -- Wait until DECODE accepts instruction
               if dc_ready_i = '1' then
                  dc_valid <= '0';

                  -- Fetch the next instruction
                  wb_addr <= std_logic_vector(unsigned(wb_addr) + 1);
                  wb_stb  <= '1';
                  wb_cyc  <= '1';
                  state   <= WAIT_REQ_ST;
               end if;

            when others => null;
         end case;

         -- React to any new PC from the DECODE stage
         if dc_valid_i = '1' then
            wb_addr <= dc_pc_i;
            wb_cyc  <= '0';      -- Abort any existing WISHBONE request
            wb_stb  <= '0';      -- Abort any existing WISHBONE request
            state   <= REQ_ST;
         end if;

         if rst_i = '1' then
            wb_cyc   <= '0';
            wb_stb   <= '0';
            dc_valid <= '0';
            state    <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Connect output signals
   wb_cyc_o   <= wb_cyc;
   wb_stb_o   <= wb_stb;
   wb_addr_o  <= wb_addr;
   dc_valid_o <= dc_valid;
   dc_addr_o  <= dc_addr;
   dc_inst_o  <= dc_inst;

end architecture synthesis;

