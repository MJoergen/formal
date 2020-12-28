library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module implements a FIFO consisting of only a single register layer.
-- It has its use in elastic pipelines, where the data flow has back-pressure.
-- It places registers on the valid and data signals in the downstream direction,
-- but the ready signal in the upstream direction is still combinatorial.

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

   -- Formal verification
   signal f_rst     : std_logic := '1';

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


   ------------------------
   -- Formal verification
   ------------------------

   formal_gen : if G_FORMAL generate

      -- set all declarations to run on clk_i
      default clock is rising_edge(clk_i);


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
      -- This is to ensure BMC starts in a valid state.
      f_reset : assume always {rst_i or not f_rst};


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- FIFO must be empty after reset
      f_after_reset : assert always {rst_i} |=>
         not m_valid_o;

      -- FIFO must be full after write
      f_fifo_full : assert always {s_valid_i and s_ready_o and not rst_i} |=>
         m_valid_o;

      -- FIFO must be empty after read with no write
      f_fifo_empty : assert always {m_valid_o and m_ready_i and not s_valid_i} |=>
         not m_valid_o;

      -- Output must be stable until accepted
      f_output_stable : assert always {m_valid_o and not m_ready_i and not rst_i} |=>
         {m_valid_o = prev(m_valid_o) and
          m_data_o  = prev(m_data_o)};


      --------------------------------------------
      -- COVER STATEMENTS TO VERIFY REACHABILITY
      --------------------------------------------

      -- Make sure FIFO can transition from full to empty.
      f_full_to_empty : cover {m_valid_o and not rst_i; not m_valid_o};

   end generate formal_gen;
end architecture synthesis;

