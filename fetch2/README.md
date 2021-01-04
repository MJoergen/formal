# FETCH module of a yet-to-be-made CPU (optimized version)

The [previous version](../fetch) of the FETCH module was not completely
optimized, and in particular could not sustain a 100% throughput even in best
case.  In this optimized version of the FETCH module I will rewrite the module
from scratch to get better performance.

## Implementation

The strategy this time is much different. From the previous version I was
quickly overwhelmed by complexity, even for such a simple module. So this time
I will use a more hierarchical and general approach.

The idea is to consider the WISHBONE interface as two independent data streams:
A sequence of addresses going out, and a corresponding sequence of data coming
in.  And pairs of (address,data) is to be sent to the DECODE stage.

Therefore, I instantiate two FIFOs. The first FIFO is filled with the stream
of addresses sent to the WISHBONE interface, and the second FIFO is filled with
the streams of data received from the WISHBONE interface. Finally, the outputs
of these two FIFOs are concatenated and sent to the DECODE stage.

In this particular version I expect the WISHBONE data to arrive on the next
clock cycle, i.e. a latency of just one clock cycle. Therefore, at most two
requests need to be stored in the address FIFO, and we can therefore use the
pre-existing [two_stage_fifo](../two_stage_fifo). And to reduce latency I
notice that the data FIFO can just be a simple
[one_stage_buffer](../one_stage_buffer). So the bulk of the implementation is
shown in the skeleton code below:

```
i_two_stage_fifo_addr : entity work.two_stage_fifo
   port map (
      s_valid_i => wb_cyc_o and wb_stb_o,
      s_ready_o => tsf_in_addr_ready,
      s_data_i  => wb_addr_o,
      m_data_o  => tsf_out_addr_data
      etc...

i_two_stage_buffer_data : entity work.two_stage_buffer
   port map (
      s_valid_i => wb_cyc_o and wb_ack_i,
      s_ready_o => tsb_in_data_ready,
      s_data_i  => wb_data_i,
      m_data_o  => tsb_out_data_data
      etc...

i_pipe_concat : entity work.pipe_concat
   port map (
      s1_data_i              => tsf_out_addr_data,
      s0_data_i              => tsb_out_data_data,
      m_valid_o              => dc_valid_o,
      m_ready_i              => dc_ready_i,
      m_data_o(31 downto 16) => dc_addr_o,
      m_data_o(15 downto 0)  => dc_data_o
      etc...
```

With this approach I'm guaranteed that the address and data signals will always
be in sync.  The only remaining code is controlling the WISHBONE requests.

## Formal verification

In the implementation above notice that the data received from the WISHBONE
interface has no back-pressure. Therefore, we must ASSERT that the
`two_stage_buffer` always will accept the incoming data. This is handled by the
following assertion.

```
f_data_ready : assert always {wb_cyc_o and wb_ack_i} |-> {tsb_in_data_ready};
```

The same property must hold because the address entering the address fifo also
has no back pressure. So we have the corresponding ASSERT on the address fifo
input:

```
f_addr_ready : assert always {wb_cyc_o and wb_stb_o} |-> {tsf_in_addr_ready};
```

Note that these two assertions make use of the internal signals
`tsb_in_data_ready` and `tsf_in_addr_ready`.

