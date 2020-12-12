# Hello World : One Stage Fifo
For my first attempt at formal verification, I've decided to work on a
one-stage FIFO.  This is basically a register with a write-enable, but with the
added ability to provide back-pressure. So the implementation contains a small
FSM revolving around whether the contents have been read.

## The protocol (how the FIFO works)
There is a producer (or source) that feeds data into the FIFO, and there is
a consumer (or sink) that reads data out of the FIFO.

Both the producer and the consumer interfaces are identical, with a DATA and
VALID signal going downstream, and a READY signal going upstream. When both
VALID and READY are asserted simultaneously on a given interface (either
producer or consumer) then the DATA is moved (either into or out of the
register).  This is a simplified version of the protocol used in [AXI streaming
interfaces](https://zipcpu.com/doc/axi-stream.pdf). It is possible to
simultaneously (i.e. in the same clock cycle) move data into the FIFO and out
of the FIFO.

Although not strictly necessary for the correct operation of this protocol,
I've added an additional constraint: When the upstream has asserted VALID, and
READY is not yet asserted, the signals DATA and VALID are required to remain
unchanged, until the data transfer has completed.  In other words, the sender
may not "change its mind" once it has announced that data is waiting.  This
requirement is not strictly necesasry, but is kind of "common sense". However,
it does mean the sender is not able to "abort" a transfer.

One thing to note about this protocol is that the upstream READY signal (back
towards the producer) is often combinatorial, whereas the downstrean VALID and
DATA signals are registered. This combinatorial path on the READY signal may
(or may not) give timing problems. This is just something to be aware of. This
combinatorial path can be registered for improved timing, but requires a
two-stage FIFO. More on that later.

## The implementation
The FIFO implementation is found [here](one_stage_fifo.vhd). This file contains
the actual implementation, an nothing more. The formal verification of the
design goes into a [separate file](one_stage_fifo_formal.sv), written in System
Verilog. Note that this latter file must have the same port declarations as the
DUT.

## Formal verification
Instead of writing a testbench manually generating stimuli, we instead write
some rules (assertions) that must be obeyed at all times.  Note: This is a
non-trivial step, and takes practice.

The main keywords to use are `assume()` (for validating input), `assert()` (for
validating output), and `cover()` (for ensuring reachability). This
[link](http://zipcpu.com/blog/2017/10/19/formal-intro.html) has much more
information on the syntax and keywords available.

### Assumption on inputs

We'll start out with a standard assumption: Everything begins in a reset state.

```
initial `ASSUME(rst_i);
```

Moving on, we require the input to obey the extra "common sense" requirement,
i.e. not to allow aborts of inputs.

```
always @(posedge clk_i)
begin
   if (f_past_valid && !rst_i && $past(s_valid_i) && $past(!s_ready_o))
   begin
      `ASSUME ($stable(s_valid_i));
      `ASSUME ($stable(s_data_i));
   end
end
```

So if the last clock cycle saw the sender trying to send data (asserting
`s_valid_i`) but the DUT not accepting it yet (de-asserting `s_ready_o`) then
the current clock cycle should see no change in the signals into the DUT.

And that is all for the inputs.

### Assertions on outputs

Similarly, we place assertions on the expected behaviour of the DUT.

First of all, we expect the FIFO to be empty right after reset.
```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(rst_i))
   begin
      assert (m_valid_o == 0);
   end
end
```

The next is to assert that the DUT does not abort.

```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(!rst_i) && $past(m_valid_o) && $past(!m_ready_i))
   begin
      assert ($stable(m_valid_o));
      assert ($stable(m_data_o));
   end
end
```

And finally, we want to assert that the FIFO can be emptied:

```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(m_valid_o) && $past(m_ready_i) && $past(!s_valid_i))
   begin
      assert (!m_valid_o);
   end
end
```


### Cover statements to verify reachability

Finally, the `cover()` statement is used to automatically generate stimuli. In
code it looks as follows:

```
generate
   genvar i;
   for (i=0; i < 8; i++) begin: CVR
      always @(posedge clk_i)
      begin
         cover (f_past_valid && $past(!rst_i) && {s_valid_i, m_ready_i, m_valid_o} == i);
      end
   end
endgenerate
```

This forces the formal verification tool to check all combinations of
`s_valid_i`, `m_ready_i`, and `m_valid_o`.


## Running the formal verifier
In order to run the formal verifier, we must create a small
script [one_stage_fifo.sby](one_stage_fifo.sby).

Then we just run the verifier using the command
```
sby --yosys "yosys -m ghdl" -f one_stage_fifo.sby
```

This command is conveniently stored in a Makefile to allow the simple command
to run verification:

```
make
```

This generates a lot of output. Among the plethora of text you should see the
lines

```
...
[one_stage_fifo_bmc] DONE (PASS, rc=0)
...
[one_stage_fifo_cover] DONE (PASS, rc=0)
...
[one_stage_fifo_prf] DONE (PASS, rc=0)
...
```

This is it! We've now formally verified that the implementation of the one
stage fifo satisfies all the formal requirements.

