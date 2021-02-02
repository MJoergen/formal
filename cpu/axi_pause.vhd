-------------------------------------------------------------------------------
-- Description:
-- This module generates empty cycles in an AXI stream by deasserting
-- m_tready_o and s_tvalid_o at regular intervals. The period between the empty
-- cycles can be controlled by the generic G_PAUSE_SIZE:
-- * Setting it to 0 disables the empty cycles.
-- * Setting it to 10 inserts empty cycles every tenth cycle, i.e. 90 % throughput.
-- * Setting it to -10 inserts empty cycles except every tenth cycle, i.e. 10 % throughput.
-- * Etc.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity axi_pause is
   generic (
      G_TDATA_SIZE : integer := 16;
      G_PAUSE_SIZE : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Input
      s_tvalid_i : in  std_logic;
      s_tready_o : out std_logic;
      s_tdata_i  : in  std_logic_vector(G_TDATA_SIZE-1 downto 0);

      -- Output
      m_tvalid_o : out std_logic;
      m_tready_i : in  std_logic;
      m_tdata_o  : out std_logic_vector(G_TDATA_SIZE-1 downto 0)
   );
end entity axi_pause;

architecture simulation of axi_pause is

   signal cnt_r : integer range 0 to abs(G_PAUSE_SIZE) := 0;

begin

   cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if G_PAUSE_SIZE /= 0 then
            -- Generate a value in range 1 to G_PAUSE_SIZE
            if (cnt_r = G_PAUSE_SIZE - 1) and (m_tvalid_o = '1') and (m_tready_i = '0') then
               -- If offering data which is not taken, do not change the valid
               -- signal, until data has been accepted.
               cnt_r <= cnt_r;
            else
               cnt_r <= (cnt_r + 1) mod abs(G_PAUSE_SIZE);
            end if;
         end if;
      end if;
   end process cnt_proc;

   no_pause_gen : if G_PAUSE_SIZE = 0 generate
      s_tready_o <= m_tready_i;
      m_tvalid_o <= s_tvalid_i;
   end generate no_pause_gen;

   pause_positive_gen : if G_PAUSE_SIZE > 0 generate
      -- Insert empty cycle when cnt_r reaches zero.
      s_tready_o <= '0' when cnt_r = 0 else
                     m_tready_i;
      m_tvalid_o <= '0' when cnt_r = 0 else
                     s_tvalid_i;
   end generate pause_positive_gen;

   pause_negative_gen : if G_PAUSE_SIZE < 0 generate
      -- Insert empty cycle except when cnt_r reaches zero.
      s_tready_o <= '0' when cnt_r /= 0 else
                     m_tready_i;
      m_tvalid_o <= '0' when cnt_r /= 0 else
                     s_tvalid_i;
   end generate pause_negative_gen;

   m_tdata_o <= s_tdata_i;

end architecture simulation;

