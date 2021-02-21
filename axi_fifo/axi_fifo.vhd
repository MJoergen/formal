library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_fifo is
  generic (
    ram_width : natural;
    ram_depth : natural
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    -- AXI input interface
    in_ready : out std_logic;
    in_valid : in std_logic;
    in_data : in std_logic_vector(ram_width - 1 downto 0);

    -- AXI output interface
    out_ready : in std_logic;
    out_valid : out std_logic;
    out_data : out std_logic_vector(ram_width - 1 downto 0)
  );
end axi_fifo;

architecture rtl of axi_fifo is

  -- The FIFO is full when the RAM contains ram_depth - 1 elements
  type ram_type is array (0 to ram_depth - 1) of std_logic_vector(in_data'range);
  signal ram : ram_type;

  -- Newest element at head, oldest element at tail
  subtype index_type is natural range ram_type'range;
  signal head : index_type;
  signal tail : index_type;
  signal count : index_type;
  signal count_p1 : index_type;

  -- Internal versions of entity signals with mode "out"
  signal in_ready_i : std_logic;
  signal out_valid_i : std_logic;

  -- True the clock cycle after a simultaneous read and write
  signal read_while_write_p1 : std_logic;

  -- Increment or wrap the index if this transaction is valid
  function next_index(
    index : index_type;
    ready : std_logic;
    valid : std_logic) return index_type is
  begin
    if ready = '1' and valid = '1' then
      if index = index_type'high then
        return index_type'low;
      else
        return index + 1;
      end if;
    end if;

    return index;
  end function;

  -- Logic for handling the head and tail signals
  procedure index_proc(
    signal clk : in std_logic;
    signal rst : in std_logic;
    signal index : inout index_type;
    signal ready : in std_logic;
    signal valid : in std_logic) is
  begin
      if rising_edge(clk) then
        if rst = '1' then
          index <= index_type'low;
        else
          index <= next_index(index, ready, valid);
        end if;
      end if;
  end procedure;

begin

  -- Copy internal signals to output
  in_ready <= in_ready_i;
  out_valid <= out_valid_i;

  -- Update head index on write
  PROC_HEAD : index_proc(clk, rst, head, in_ready_i, in_valid);

  -- Update tail index on read
  PROC_TAIL : index_proc(clk, rst, tail, out_ready, out_valid_i);

  -- Write to and read from the RAM
  PROC_RAM : process(clk)
  begin
    if rising_edge(clk) then
      ram(head) <= in_data;
      out_data <= ram(next_index(tail, out_ready, out_valid_i));
    end if;
  end process;

  -- Find the number of elements in the RAM
  PROC_COUNT : process(head, tail)
  begin
    if head < tail then
      count <= head - tail + ram_depth;
    else
      count <= head - tail;
    end if;
  end process;

  -- Delay the count by one clock cycles
  PROC_COUNT_P1 : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        count_p1 <= 0;
      else
        count_p1 <= count;
      end if;
    end if;
  end process;

  -- Set in_ready when the RAM isn't full
  PROC_IN_READY : process(count)
  begin
    if count < ram_depth - 1 then
      in_ready_i <= '1';
    else
      in_ready_i <= '0';
    end if;
  end process;

  -- Detect simultaneous read and write operations
  PROC_READ_WHILE_WRITE_P1: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        read_while_write_p1 <= '0';

      else
        read_while_write_p1 <= '0';
        if in_ready_i = '1' and in_valid = '1' and
          out_ready = '1' and out_valid_i = '1' then
          read_while_write_p1 <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Set out_valid when the RAM outputs valid data
  PROC_OUT_VALID : process(count, count_p1, read_while_write_p1)
  begin
    out_valid_i <= '1';

    -- If the RAM is empty or was empty in the prev cycle
    if count = 0 or count_p1 = 0 then
      out_valid_i <= '0';
    end if;

    -- If simultaneous read and write when almost empty
    if count = 1 and read_while_write_p1 = '1' then
      out_valid_i <= '0';
    end if;

  end process;

end architecture;
