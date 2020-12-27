library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This is a simple buffer that is transparent (combinatorial) when the
-- receiver is ready, but registers the incoming value if not.

entity one_stage_buffer is
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
end entity one_stage_buffer;

architecture synthesis of one_stage_buffer is

   signal s_ready_s : std_logic;
   signal s_valid_r : std_logic := '0';
   signal s_data_r  : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

   -- Formal verification
   signal f_last_value : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');
   signal f_count      : integer range 0 to 3 := 0;

begin

   s_ready_s <= m_ready_i or not s_valid_r;

   p_buffer : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' and s_valid_i = '0' then
            -- Receiver has consumed output
            s_valid_r <= '0';
         end if;

         if s_valid_i = '1' and m_ready_i = '0' then
            s_valid_r <= '1';
         end if;

         if s_valid_i = '1' and s_ready_s = '1' then
            s_data_r  <= s_data_i;
         end if;

         if rst_i = '1' then
            s_valid_r <= '0';
            s_data_r  <= (others => '0');
         end if;
      end if;
   end process p_buffer;

   -- Connect output signals
   s_ready_o <= s_ready_s;
   m_data_o  <= s_data_r when s_valid_r = '1' else s_data_i;
   m_valid_o <= (s_valid_r or s_valid_i) and not rst_i;


   ------------------------
   -- Formal verification
   ------------------------

   formal_gen : if G_FORMAL generate

      -- set all declarations to run on clk_i
      default clock is rising_edge(clk_i);


      -----------------------------
      -- ASSUMPTIONS ABOUT INPUTS
      -----------------------------

      -- Input must be stable until accepted
      assume always {s_valid_i and not s_ready_o} |=>
         {s_valid_i = prev(s_valid_i) and
          s_data_i  = prev(s_data_i)} abort rst_i;


      -----------------------------
      -- ASSERTIONS ABOUT OUTPUTS
      -----------------------------

      -- Buffer must be empty after reset, unless new incoming data
      assert always {rst_i} |=>
         {not m_valid_o} abort s_valid_i;

      -- Output must be stable until accepted
      assert always {m_valid_o and not m_ready_i} |=>
         {m_valid_o = prev(m_valid_o) and
          m_data_o  = prev(m_data_o)} abort rst_i;

      -- Keep track of data flowing into and out of the buffer
      process (clk_i)
      begin
         if rising_edge(clk_i) then
            if s_valid_i and s_ready_o then
               f_last_value <= s_data_i;
            end if;

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
      end process;

      -- The buffer size is limited to 1.
      assert always {0 <= f_count and f_count <= 1};

      -- If data is flowing in, but not out, then the buffer must be empty
      assert always {s_valid_i and s_ready_o and m_valid_o and not m_ready_i} |->
         f_count = 0;

      -- If data is flowing out, but not in, then the buffer must be full
      assert always {m_valid_o and m_ready_i and not s_valid_i and s_ready_o} |->
         f_count = 1;

      -- If buffer is full, it must always present data on output
      assert always {f_count /= 0} |->
         {m_valid_o = '1' and
         m_data_o = f_last_value} abort rst_i;


      --------------------------------------------
      -- COVER STATEMENTS TO VERIFY REACHABILITY
      --------------------------------------------

      -- Make sure FIFO can transition from full to empty.
      cover {m_valid_o; not m_valid_o};

   end generate formal_gen;

end architecture synthesis;

