# Formal verification

Others have gone here before me, and now it is my turn!

[Formal verification](http://zipcpu.com/blog/2017/10/19/formal-intro.html) is a
tool for verifying the correctness of your implementation. Traditional
verification strategies have relied on hand-crafted testbenches to provide
stimuli to the DUT.  Formal verification aims to automate that process. In my
view the two approaches (testbench and formal) supplement each other, rather
than replacing each other.

I'm currently using Verilog as implementation language, mainly because the
documentation is more abundant. However, I would like to do [formal
verification in
VHDL](http://pepijndevos.nl/2019/08/15/open-source-formal-verification-in-vhdl.html)
when I have more experience.

The tool I'm using for formal verification is
[SymbiYosys](https://github.com/YosysHQ/SymbiYosys).

## Hello World : One Stage Fifo
For my first attempt at formal verification, I've decided to work on a
one-stage FIFO.  This is basically a register with a write-enable, but with the
added ability to provide back-pressure. So the implementation contains a small
FSM revolving around whether the contents have been read.

### The protocol (how the FIFO works)

So there is a producer (or source) that feeds data into the FIFO, and there is
a consumer (or sink) that reads data out of the FIFO.

Both the producer and and the consumer interfaces are identical, with a DATA
and VALID signal going downstream, and a READY signal going upstream. When both
VALID and READY are asserted simultaneously on a given interface (either
producer or consumer) then the DATA is moved.

Although not strictly necessary for the correct operation of this protocol,
I've added an additional constraint: When the upstream has asserted VALID, and
READY is not yet asserted, the signals DATA and VALID are required to remain
unchanged, until the data transfer has completed.  In other words, the sender
may not "change its mind" once it has announced that data is waiting.  This
requirement is kind of "common sense", but it's not strictly necessary.

One thing to note about this protocol is that the upstream READY (back to
producer) is often combinatorial, whereas the downstrean VALID and DATA are
registered. This combinatorial path on the READY signal may give timing
problems, and indeed it can be alleviated, but requires a two-stage FIFO. This
will be done later.

### The implementation
The FIFO implementation is found [here](one_stage_fifo/one_stage_fifo.sv).  The
first half of the source file is the actual implementation, while the second
half (surrounded by `ifdef FORMAL` and `endif`) contains the formal
verification.

### Formal verification
Instead of writing a testbench manually generating stimuli, we have to write a
bunch of rules (assertions) that must be obyed at all times.  This is a
non-trivial step and takes practice.  The main keywords to use are `assume`
(for validating input), `assert` (for validating output), and `cover` (for
generating stimuli).

For now I'm only checking that the producer and consumer interfaces obey the
extra "common sense" requirement. For the producer interface, it looks as follows:

```
if ($past(s_valid_i) && $past(!s_ready_o))
begin
   assume ($stable(s_valid_i));  // s_valid_i must the same as the last clock cycle
   assume ($stable(s_data_i));   // s_data_i must the same as the last clock cycle
end
```

So if the last clock cycle saw the sender trying to send data (asserting
`s_valid_i`) but the receiver not accepting it yet (de-asserting `s_ready_o`)
then the current clock cycle should see no change in the signals from the
sender.

There is a similar block of code for the consumer interface:

```
if ($past(m_valid_o) && $past(!m_ready_i))
begin
   assert ($stable(m_valid_o));  // m_valid_o must the same as the last clock cycle
   assert ($stable(m_data_o));   // m_data_o must the same as the last clock cycle
end
```

The following section verifies that the FIFO is empty immediately after de-asserting reset:

```
if (past_valid && $fell(rst_i))
begin
   assert (m_valid_o == 0);          // m_data_o must be cleared after reset
end
```

Finally, the `cover` statement is used to automatically generate stimuli. In code it looks as follows:

```
for (i=0; i < 8; i++) begin: CVR
   always @(posedge clk_i)
   begin
      cover (past_valid && !rst_i && {s_valid_i, m_ready_i, m_valid_o} == i);
   end
end
```

This forces the formal verification tool to check all combinations of
`s_valid_i`, `m_ready_i`, and `m_valid_o`.

### Install SymbiYosys
First you have to clone the SymbiYosys [repository](https://github.com/YosysHQ/SymbiYosys) and then run

```
sudo make install
```

and

```
make html
```

The latter command generates the documentation in the subfolder
`docs/build/html`. In particular, the file `install.html` contains instructions
for installing the backend `yosys` tool.

### Running the formal verifier
In order to run the formal verifier, we must create a small [script](one_stage_fifo/one_stage_fifo.sby).

The we just run the verifier using the command
```
sby one_stage_fifo.sby
```

This generates a lot of output. Among the plethora of text you should see the lines

```
[one_stage_fifo_bmc] DONE (PASS, rc=0)
```

and

```
[one_stage_fifo_cover] DONE (PASS, rc=0)
```

This is it.
