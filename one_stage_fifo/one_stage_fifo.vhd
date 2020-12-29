library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module implements a FIFO consisting of only a single register layer.
-- It has its use in elastic pipelines, where the data flow has back-pressure.
-- It places registers on the valid and data signals in the downstream direction,
-- but the ready signal in the upstream direction is still combinatorial.
-- The FIFO supports simultaneous read and write, both when the FIFO is full
-- and when it is empty.

entity one_stage_fifo is
   generic (
      G_FORMAL    : boolean := false;
      G_DATA_SIZE : integer := 8
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_data_i  : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_data_o  : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end entity one_stage_fifo;

architecture synthesis of one_stage_fifo is

   signal s_ready_s : std_logic;
   signal m_valid_r : std_logic;
   signal m_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

   -- We accept data from upstream in two situations:
   -- * When FIFO is empty.
   -- * When downstream is ready.
   -- The latter situation allows simultaneous read and write, even when the
   -- FIFO is full.
   s_ready_s <= m_ready_i or not m_valid_r;

   p_fifo : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Downstream has consumed the output
         if m_ready_i = '1' then
            m_valid_r <= '0';
         end if;

         -- Valid data on the input
         if s_ready_s = '1' and s_valid_i = '1' then
            m_data_r  <= s_data_i;
            m_valid_r <= '1';
         end if;

         -- Reset empties the FIFO
         if rst_i = '1' then
            m_valid_r <= '0';
         end if;
      end if;
   end process p_fifo;

   -- Connect output signals
   s_ready_o <= s_ready_s;
   m_valid_o <= m_valid_r;
   m_data_o  <= m_data_r;


   formal_gen : if G_FORMAL generate

      -- Additional signals used during formal verification
      signal f_rst        : std_logic := '1';
      signal f_last_value : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');
      signal f_count      : integer range 0 to 3 := 0;

   begin


      ------------------------
      -- Formal verification
      ------------------------

      -- set all declarations to run on clk_i
      -- psl default clock is rising_edge(clk_i);


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- FIFO must be empty after reset
      -- psl f_after_reset : assert always {rst_i} |=> not m_valid_o;

      -- Output must be stable until accepted
      -- psl f_output_stable : assert always {m_valid_o and not m_ready_i and not rst_i} |=> {stable(m_valid_o) and stable(m_data_o)};

      -- Keep track of amount of data flowing into and out of the FIFO
      p_count : process (clk_i)
      begin
         if rising_edge(clk_i) then
            -- Data flowing in, but not out.
            if s_valid_i and s_ready_o and not (m_valid_o and m_ready_i) then
               f_count <= f_count + 1;
            end if;

            -- Data flowing out, but not in.
            if m_valid_o and m_ready_i and not (s_valid_i and s_ready_o) then
               f_count <= f_count - 1;
            end if;

            if rst_i then
               f_count <= 0;
            end if;
         end if;
      end process p_count;

      -- Keep track of data flowing into and out of the FIFO
      p_last_value : process (clk_i)
      begin
         if rising_edge(clk_i) then
            -- Remember last value written into FIFO
            if s_valid_i and s_ready_o then
               f_last_value <= s_data_i;
            end if;
         end if;
      end process p_last_value;

      -- The FIFO size is limited to 1.
      -- psl f_size : assert always {0 <= f_count and f_count <= 1};

      -- If FIFO is full, it must always present valid data on output
      -- psl f_count_1 : assert always {f_count = 1} |-> {m_valid_o = '1' and m_data_o = f_last_value} abort rst_i;

      -- If FIFO is empty, no data present on output
      -- psl f_count_0 : assert always {f_count = 0} |-> {m_valid_o = '0'} abort rst_i;


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
      -- psl f_full_to_empty : cover {m_valid_o and not rst_i; not m_valid_o};

   end generate formal_gen;

end architecture synthesis;

