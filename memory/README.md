# MEMORY module of a yet-to-be-made CPU (optimized version)

When designing and connecting the different blocks that make up the CPU I find
it convenient to make use of "elastic pipelines", i.e. where the interface
consists of a `valid` signal from source to sink, and a `ready` signal from the
sink back to the source. However, the WISHBONE protocol is not as easy, because
the WISHBONE response signal `wb_ack_i` can not be delayed.

Therefore, I find it convenient to introduce the MEMORY module, which acts as
an "adapter" from the WISHBONE interface to the "elastic pipeline" interface.

## Interface

The MEMORY module exposes a source interface (connected to the EXECUTE module)
as follows:
```
s_valid_i    : in  std_logic;
s_ready_o    : out std_logic;
s_op_i       : in  std_logic_vector(2 downto 0);
s_addr_i     : in  std_logic_vector(15 downto 0);
s_data_i     : in  std_logic_vector(15 downto 0);
```

The `s_op_i` is a one-hot encoding of the requested operation:
* Write `data` to `addr`.
* Read from `addr` and place result in `src`.
* Read from `addr` and place result in `dst`.

The `src` and `dst` interfaces mentioned here are two output pipelines:
```
msrc_valid_o : out std_logic;
msrc_ready_i : in  std_logic;
msrc_data_o  : out std_logic_vector(15 downto 0);

mdst_valid_o : out std_logic;
mdst_ready_i : in  std_logic;
mdst_data_o  : out std_logic_vector(15 downto 0);
```

The idea is that the EXECUTE block issues requests and reads back the results
at a later time.

The main benefit of this module is that it stores the results read back from
memory, in case the EXECUTE module is not ready to receive it yet.

## Implementation

## Formal verification

## Running formal verification
![Waveform](waveform.png)

## Synthesis
```
Number of cells:                220
  BUFG                            1
  FDRE                           37
  IBUF                           58
  LUT2                            6
  LUT3                           42
  LUT5                            2
  LUT6                            4
  OBUF                           70

Estimated number of LCs:         48
```

