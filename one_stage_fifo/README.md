# Hello World : One Stage Fifo
For my first attempt at formal verification, I've decided to work on a
one-stage FIFO.  This is basically a register with a write-enable, but with the
added ability to provide back-pressure. So the implementation contains a small
FSM revolving around whether or not the FIFO contains valid data.

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
of the FIFO, regardless of whether the FIFO is empty or full.

Although not strictly necessary for the correct operation of this protocol,
I've added an additional constraint: When the upstream has asserted VALID, and
READY is not yet asserted, the signals DATA and VALID are required to remain
unchanged, until the data transfer has completed.  In other words, the sender
may not "change its mind" once it has announced that data is waiting.  This
requirement is not strictly necessary, but is kind of "common sense". However,
it does mean the sender is not able to "abort" a transfer.

One thing to note about this protocol is that the upstream READY signal (back
towards the producer) is often combinatorial, whereas the downstrean VALID and
DATA signals are registered. This combinatorial path on the READY signal may
(or may not) give timing problems. This is just something to be aware of. This
combinatorial path can be registered for improved timing, but requires a
two-stage FIFO. More on that later.

## The implementation
The FIFO implementation is found [here](one_stage_fifo.vhd). This file contains
both the actual implementation and the additional commands for formal verification.

## Formal verification
Instead of writing a testbench that manually generates stimuli, we instead
write some rules (assertions) that must be obeyed at all times.  Note: This is
a non-trivial step, and takes considerable practice.

The main keywords to use are `assume` (for validating input), `assert` (for
validating output), and `cover` (for ensuring reachability).

Sometime additional logic is needed for formal verification. For that reason,
I add the generic `G_FORMAL : boolean := false` to the design. Furthermore,
I wrap the entire section of formal verification inside a `generate` statement
as follows:

```
formal_gen : if G_FORMAL generate
end generate formal_gen;
```

That way, any logic related to formal verification will not be included during
normal synthesis.

One final general thing about formal verification is that it is synchronous,
and therefore requires specifying a clock. Since most entities use only
a single clock, this can be selected efficiently by this single line:

```
default clock is rising_edge(clk_i);
```

### Assertions on outputs
We're now ready to start expressing the properties of the FIFO as assertions on
the outputs.

The first simple requirement is that after a reset the FIFO must be empty. This
is described by this command:

```
f_after_reset : assert always {rst_i} |=>
   not m_valid_o;
```

The word `f_after_reset` is just a label. I like to use the naming convention
of having every label related to formal verification begin with `f_`.

The symbol `|=>` means "assert on the next clock cycle". So if `rst_i` is
asserted at some time, then on the very next clock cycle `m_valid_o` must be
false.

Next we may assert that after a write, the FIFO should be full.
```
f_fifo_full : assert always {s_valid_i and s_ready_o and not rst_i} |=>
   m_valid_o;
```
The write is indicated by the combination `s_valid_i and s_ready_o`.  Notice
here, we also need a condition on the reset signal.

Thirdly we may want to assert that after a read with no write, the FIFO is again
empty.
```
f_fifo_empty : assert always {m_valid_o and m_ready_i and not s_valid_i} |=>
   not m_valid_o;
```
The combination `m_valid_o and m_ready_i` indicates the FIFO is being read, and
the `not s_valid_i` states there is no write taking place. On the next clock
cycle, the FIFO should then be empty.

Finally, we assert the additional property that the output remains stable until
read.
```
f_output_stable : assert always {m_valid_o and not m_ready_i and not rst_i} |=>
   {m_valid_o = prev(m_valid_o) and
    m_data_o  = prev(m_data_o)};
```
Here the combination `m_valid_o and not m_ready_i` indicates the FIFO is full,
but the data is not read yet. Then on the next clock cycle, the outputs from
the FIFO should be unchanged.

### Assumptions about inputs
Sometimes we have to impose restrictions on the inputs.  We use the `assume`
keyword to restrict the allowed inputs.

For instance, one such requirement is that we start of in a reset condition.
This can be written as follows:
```
f_reset : assume always {rst_i or not f_rst};
```

Here we're referencing a new signal `f_rst` only used by formal verification.
This signals starts out as true, and transitions to false on the very next
clock cycle.

Note here we do not require `rst_i` and `f_rst` to be equal. This is because
we leave open the possibility of `rst_i` being asserted again at a later
time. The only hard requirement we impose is that the very first clock
cycle has `rst_i` asserted.

The generation of the `f_rst` signal is done simply by:
```
process (clk_i)
begin
   if rising_edge(clk_i) then
      f_rst <= '0';
   end if;
end process;
```
and with an appropriate initial value:

```
signal f_rst : std_logic := '1';
```

### Cover statements to verify reachability

Finally, the `cover` statement is used to automatically generate stimuli.

For this simple FIFO I've chosen to detect the situation where the FIFO
transitions from full to empty.

```
f_full_to_empty : cover {m_valid_o and not rst_i; not m_valid_o};
```

Note here the use of `;` inside the `{}`. The symbol `;` indicates the passage
of one clock cycle. So the expression `{m_valid_o and not rst_i; not
m_valid_o}` states that on one clock cycle the FIFO should be full and with no
reset, and then on the **next** clock cycle the FIFO should be empty. So this
is a two-clock-cycle sequence of signals.

By writing `cover` statements the formal verification tool will automatically
try to generate the stimuli necessary to satisfy the condition. On other words,
the tool writes the testbench for you!

## Running the formal verifier
In order to run the formal verifier, we must create a small
script [one_stage_fifo.sby](one_stage_fifo.sby).

The tricky line in the script is the following:
```
ghdl -fpsl --std=08 -gG_FORMAL=true one_stage_fifo.vhd -e one_stage_fifo
```
The command line parameters `-fpsl --std=08` are necessary to enable the PSL
verification language. The parameter `-gG_FORMAL=true` sets the value
of the generic `G_FORMAL` we added,

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

