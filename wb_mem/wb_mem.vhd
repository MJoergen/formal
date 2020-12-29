library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A simple memory with a Wishbone Slave interface.

entity wb_mem is
   generic (
      G_FORMAL    : boolean := false;
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

   -- Initial memory contents
   signal mem_r : mem_t := (others => (others => '0'));

   signal wb_ack_r  : std_logic := '0';
   signal wb_data_r : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   -- Writing to memory
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wb_cyc_i = '1' and wb_stb_i = '1' and wb_stall_o = '0' and wb_we_i = '1' then
            mem_r(to_integer(unsigned(wb_addr_i))) <= wb_data_i;
         end if;
      end if;
   end process p_write;

   -- Reading from memory
   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wb_ack_r  <= '0';

         if wb_cyc_i = '1' and wb_stb_i = '1' and wb_stall_o = '0' then
            if wb_we_i = '0' then
               wb_data_r <= mem_r(to_integer(unsigned(wb_addr_i)));
            end if;
            wb_ack_r  <= '1'; -- This also ACK's the write transaction.
         else
            wb_data_r <= (others => '0');
         end if;
      end if;
   end process p_read;

   -- Connect output signals
   wb_stall_o <= rst_i;
   wb_ack_o   <= wb_ack_r;
   wb_data_o  <= wb_data_r;


   ------------------------
   -- Formal verification
   ------------------------

   formal_gen : if G_FORMAL generate

      -- Additional signals used during formal verification
      signal f_rst   : std_logic := '1';
      signal f_count : integer range 0 to 3 := 0;

   begin

      -- set all declarations to run on clk_i
      -- psl default clock is rising_edge(clk_i);


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- When wb_ack_o is de-asserted, then wb_data_o is all zeros.
      -- psl f_data_zero : assert always {not wb_ack_o} |-> {or(wb_data_o) = '0'};

      -- When writing to memory, the data output is unchanged.
      -- psl f_data_stable : assert always {wb_cyc_i and wb_stb_i and wb_we_i and not rst_i} |=> {stable(wb_data_o)};

      -- The response always appears on the exact following clock cycle, i.e. a fixed latency of 1.
      -- psl f_ack_next : assert always {wb_cyc_i and wb_stb_i and wb_we_i and not rst_i} |=> {wb_ack_o};

      -- No ACKs allowed when the bus is idle.
      -- psl f_ack_idle : assert always {not (wb_cyc_i and wb_stb_i)} |=> {not wb_ack_o};

      -- Keep track of outstanding requests
      p_count : process (clk_i)
      begin
         if rising_edge(clk_i) then
            -- Request without response
            if wb_cyc_i and wb_stb_i and not (wb_ack_o) then
               f_count <= f_count + 1;
            end if;

            -- Reponse without request
            if not(wb_cyc_i and wb_stb_i) and wb_ack_o then
               f_count <= f_count - 1;
            end if;

            if rst_i or not wb_cyc_i then
               f_count <= 0;
            end if;
         end if;
      end process p_count;

      -- At most one outstanding request
      -- psl f_outstanding : assert always {0 <= f_count and f_count <= 1};

      -- No ACK without outstanding request
      -- psl f_count_0 : assert always {f_count = 0} |-> {not wb_ack_o};

      -- ACK always comes immediately after an outstanding request
      -- psl f_count_1 : assert always {f_count = 1} |-> {wb_ack_o};

      -- Low CYC aborts all transactions
      -- psl f_idle : assert always {not wb_cyc_i} |=> {f_count = 0};


      -----------------------------
      -- ASSUMPTIONS ABOUT INPUTS
      -----------------------------

      process (clk_i)
      begin
         if rising_edge(clk_i) then
            f_rst <= '0';
         end if;
      end process;

      -- Require reset at startup.
      -- psl f_reset : assume always {rst_i or not f_rst};


      --------------------------------------------
      -- COVER STATEMENTS TO VERIFY REACHABILITY
      --------------------------------------------

      -- Make sure FIFO can transition from full to empty.
      -- psl f_full_to_empty : cover {f_count = 1; f_count = 0};

   end generate formal_gen;

end architecture synthesis;

