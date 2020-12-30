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
   generic (
      G_FORMAL : boolean := false
   );
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
   signal wb_cyc    : std_logic := '0';
   signal wb_stb    : std_logic := '0';
   signal wb_addr   : std_logic_vector(15 downto 0);
   signal dc_valid  : std_logic := '0';
   signal dc_addr   : std_logic_vector(15 downto 0);
   signal dc_data   : std_logic_vector(15 downto 0);

   -- Combinatorial signals
   signal wb_wait   : std_logic;

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

         -- Increment address when response received
         if wb_cyc = '1' and wb_ack_i = '1' then
            wb_addr <= std_logic_vector(unsigned(wb_addr) + 1);
         end if;

         -- Start new transaction when response received and ready to issue new request
         if wb_wait = '0' and (osb_out_valid = '0' or (osb_in_valid = '0' and osb_out_ready = '1')) then
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


   ------------------------
   -- Formal verification
   ------------------------

   formal_gen : if G_FORMAL generate

      signal f_count           : integer range 0 to 3 := 0;
      signal f_req_addr        : std_logic_vector(15 downto 0) := (others => '0');
      signal f_dc_wait_count   : integer range 0 to 3;
      signal f_last_addr_valid : std_logic := '0';
      signal f_last_addr       : std_logic_vector(15 downto 0) := (others => '0');

   begin

      -- set all declarations to run on clk
      -- psl default clock is rising_edge(clk_i);


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- Keep track of addresses expected to be requested on the WISHBONE bus
      process (clk_i)
      begin
         if rising_edge(clk_i) then
            if wb_cyc_o = '1' and wb_ack_i = '1' then
               f_req_addr <= std_logic_vector(unsigned(f_req_addr) + 1);
            end if;

            if dc_valid_i = '1' then
               f_req_addr <= dc_addr_i;
            end if;
         end if;
      end process;

      -- Verify address requested on WISHBONE bus is as expected
      -- psl f_wishbone_addr : assert always {wb_cyc_o and wb_stb_o} |-> wb_addr_o = f_req_addr;

      -- Count the number of outstanding requests
      p_count : process (clk_i)
      begin
         if rising_edge(clk_i) then
            -- Request without response
            if wb_cyc_o and wb_stb_o and not wb_stall_i and not (wb_ack_i) then
               f_count <= f_count + 1;
            end if;

            -- Reponse without request
            if not(wb_cyc_o and wb_stb_o and not wb_stall_i) and wb_ack_i then
               f_count <= f_count - 1;
            end if;

            -- If CYC goes low mid-transaction, the transaction is aborted.
            if rst_i or not wb_cyc_o then
               f_count <= 0;
            end if;
         end if;
      end process p_count;

      -- At most one outstanding request
      -- psl f_outstanding : assert always {0 <= f_count and f_count <= 1};

      -- STB must be low when CYC is low.
      -- psl f_stb_low : assert always {not wb_cyc_o} |-> {not wb_stb_o};

      -- While STB and STALL are active, the request cannot change.
      -- psl f_wb_stable : assert always {wb_stb_o and wb_stall_i and not dc_valid_i and not rst_i} |=> {stable(wb_stb_o) and stable(wb_addr_o)};



      -- Verify data sent to DECODE satisfies the same artifical constraint as
      -- the WISHBONE interface.
      -- psl f_decode_data : assert always {dc_valid_o} |-> dc_data_o = not dc_addr_o;

      -- Record the last valid address sent to the DECODE stage
      process (clk_i)
      begin
         if rising_edge(clk_i) then
            if dc_valid_o = '1' then
               f_last_addr_valid <= '1';
               f_last_addr <= dc_addr_o;
            end if;

            if rst_i = '1' or dc_valid_i = '1' then
               f_last_addr_valid <= '0';
            end if;
         end if;
      end process;

      -- Validate that the address forwarded to the DECODE stage continuously
      -- increments by one.
      -- psl f_decode_addr : assert always {dc_ready_i; f_last_addr_valid and dc_valid_o} |-> {dc_addr_o = std_logic_vector(unsigned(f_last_addr) + 1)};

      -- psl f_decode_request : assert always {dc_ready_i; dc_valid_o} |-> f_req_addr = std_logic_vector(unsigned(dc_addr_o) + 1);

      -- psl f_decode_stable : assert always {dc_valid_o and not dc_ready_i} |=> {stable(dc_valid_o) and stable(dc_addr_o) and stable(dc_data_o)} abort rst_i or dc_valid_i;


      -----------------------------
      -- ASSUMPTIONS ABOUT INPUTS
      -----------------------------

      -- Require reset at startup.
      -- This is to ensure BMC starts in a valid state.
      -- psl f_reset : assume {rst_i};

      -- Assume DECODE starts by sending a new PC right after reset.
      -- This is to ensure BMC starts in a valid state.
      -- psl f_decode_after_reset : assume always {rst_i} |=> dc_valid_i;

      -- Count the number of cycles we are waiting for DECODE stage to accept
      process (clk_i)
      begin
         if rising_edge(clk_i) then
            if dc_valid_o and not dc_ready_i then
               f_dc_wait_count <= f_dc_wait_count + 1;
            else
               f_dc_wait_count <= 0;
            end if;

            if rst_i then
               f_dc_wait_count <= 0;
            end if;
         end if;
      end process;

      -- Artifically constrain the maximum amount of time the DECODE may stall
      -- psl f_decode_wait : assume always {f_dc_wait_count < 3};

      -- We want to make sure that the DECODE stage receives the correct data.
      -- We do this by artifically constraining the data received on the WISHBONE
      -- interface.
      -- psl f_wishbone_data : assume always {wb_cyc_o and wb_ack_i} |-> wb_data_i = not wb_addr_o;

      -- Only ACK an outstanding request
      -- psl f_count_0 : assume always {f_count = 0} |-> not wb_ack_i;


      --------------------------------------------
      -- COVER STATEMENTS TO VERIFY REACHABILITY
      --------------------------------------------

      -- DECODE stage accepts data
      -- psl f_decode_accept : cover {dc_valid_o; not dc_valid_o};

      -- DECODE stage receives two data cycles back-to-back
      -- psl f_decode_back2back : cover {dc_valid_o and dc_ready_i; dc_valid_o};

   end generate formal_gen;

end architecture synthesis;

