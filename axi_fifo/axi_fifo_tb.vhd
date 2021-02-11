library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

entity axi_fifo_tb is
end axi_fifo_tb; 

architecture sim of axi_fifo_tb is

  -- Testbench constants
  constant clock_period : time := 10 ns;
  constant ram_width : natural := 16;
  constant ram_depth : natural := 256;

  -- DUT signals
  signal clk : std_logic := '1';
  signal rst : std_logic := '1';
  signal in_ready : std_logic;
  signal in_valid : std_logic := '0';
  signal in_data : std_logic_vector(ram_width - 1 downto 0) := (others => '0');
  signal out_ready : std_logic := '0';
  signal out_valid : std_logic;
  signal out_data : std_logic_vector(ram_width - 1 downto 0);

begin

  clk <= not clk after clock_period / 2;

  DUT : entity work.axi_fifo(rtl)
  generic map (
    ram_width => ram_width,
    ram_depth => ram_depth
  )
  port map (
    clk => clk,
    rst => rst,
    in_ready => in_ready,
    in_valid => in_valid,
    in_data => in_data,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data
  );

  PROC_SEQUENCER : process is
  begin

    wait for 10 * clock_period;
    rst <= '0';
    wait until rising_edge(clk);

    report "Writing to the AXI FIFO";
    
    -- Write until full
    in_valid <= '1';
    while in_ready = '1' loop
      in_data <= std_logic_vector(unsigned(in_data) + 1);
      wait until rising_edge(clk);
    end loop;
    in_valid <= '0';
      
    in_data <= (others => 'X');
    
    report "Reading from the AXI FIFO";
    
    -- Read until empty
    out_ready <= '1';
    while out_valid = '1' loop
      wait until rising_edge(clk);
    end loop;
    out_ready <= '0';
      
    report "Test completed. Check waveform.";
    finish;
  end process;

end architecture;