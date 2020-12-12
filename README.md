# Formal verification

Others have gone here before me, and now it is my turn!

[Formal verification](http://zipcpu.com/formal/formal.html) is a
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

There is a producer (or source) that feeds data into the FIFO, and there is
a consumer (or sink) that reads data out of the FIFO.

Both the producer and the consumer interfaces are identical, with a DATA and
VALID signal going downstream, and a READY signal going upstream. When both
VALID and READY are asserted simultaneously on a given interface (either
producer or consumer) then the DATA is moved (either into or out of the
register).  This is a simplified version of the protocol used in [AXI streaming
interfaces](https://zipcpu.com/doc/axi-stream.pdf).

Although not strictly necessary for the correct operation of this protocol,
I've added an additional constraint: When the upstream has asserted VALID, and
READY is not yet asserted, the signals DATA and VALID are required to remain
unchanged, until the data transfer has completed.  In other words, the sender
may not "change its mind" once it has announced that data is waiting.  This
requirement is kind of "common sense", but it's not strictly necessary.

One thing to note about this protocol is that the upstream READY signal (back
towards the producer) is often combinatorial, whereas the downstrean VALID and
DATA are registered. This combinatorial path on the READY signal may (or may
not) give timing problems. This is just something to be aware of. This
combinatorial path can be registered for improved timing, but requires a
two-stage FIFO. More on that later.

### The implementation
The FIFO implementation is found [here](one_stage_fifo/one_stage_fifo.sv).  The
first half of the source file is the actual implementation, while the second
half (surrounded by ``ifdef FORMAL` and ``endif`) contains the formal
verification.

### Formal verification
Instead of writing a testbench manually generating stimuli, we have to write a
bunch of rules (assertions) that must be obeyed at all times.  This is a
non-trivial step and takes practice.  The main keywords to use are `assume()`
(for validating input), `assert()` (for validating output), and `cover()` (for
generating stimuli). This
[link](http://zipcpu.com/blog/2017/10/19/formal-intro.html) has much more
information on the syntax and keywords available.

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

The following section verifies that the FIFO is empty immediately after
de-asserting reset:

```
if (past_valid && $fell(rst_i))
begin
   assert (m_valid_o == 0);          // m_data_o must be cleared after reset
end
```

Finally, the `cover()` statement is used to automatically generate stimuli. In
code it looks as follows:

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
First you have to install `sphinx-build` as follows:

```
sudo apt install python3-sphinx
```

Then you have to clone the SymbiYosys
[repository](https://github.com/YosysHQ/SymbiYosys) and then run

```
sudo make install
```

and

```
make html
```

The latter command generates the documentation in the subfolder
`docs/build/html`. In particular, the file `install.html` contains instructions
for installing the backend `yosys` and all its dependencies tool.

One note though. One of the dependencies failed to install on one of my
machines (running GCC 9.3), while it worked fine on another machine (running
GCC 7.5). The problem is encountered in the Avy project with the following
error:

```
extavy/avy/src/ItpMinisat.h:127:52: error: cannot convert ‘boost::logic::tribool’ to ‘bool’ in return
  127 |     bool isSolved () { return m_Trivial || m_State || !m_State; }
      |                               ~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~
      |                                                    |
      |                                                    boost::logic::tribool
```

I fixed this by applying the following patch:

```
extavy/avy ((0db110e...)) $ git diff
diff --git a/src/ItpGlucose.h b/src/ItpGlucose.h
index 657253d..4ffe55f 100644
--- a/src/ItpGlucose.h
+++ b/src/ItpGlucose.h
@@ -126,7 +126,7 @@ namespace avy
     ::Glucose::Solver* get () { return m_pSat; }

     /// true if the context is decided
-    bool isSolved () { return m_Trivial || m_State || !m_State; }
+    bool isSolved () { return bool{m_Trivial || m_State || !m_State}; }

     int core (int **out)
     {
@@ -182,7 +182,7 @@ namespace avy
     bool getVarVal(int v)
     {
         ::Glucose::Var x = v;
-        return tobool (m_pSat->modelValue(x));
+        return bool{tobool (m_pSat->modelValue(x))};
     }
   };

diff --git a/src/ItpMinisat.h b/src/ItpMinisat.h
index d145d7c..7514f31 100644
--- a/src/ItpMinisat.h
+++ b/src/ItpMinisat.h
@@ -124,7 +124,7 @@ namespace avy
     ::Minisat::Solver* get () { return m_pSat.get (); }

     /// true if the context is decided
-    bool isSolved () { return m_Trivial || m_State || !m_State; }
+    bool isSolved () { return bool{m_Trivial || m_State || !m_State}; }

     int core (int **out)
     {
```



### Running the formal verifier
In order to run the formal verifier, we must create a small
[script](one_stage_fifo/one_stage_fifo.sby).

The we just run the verifier using the command
```
sby one_stage_fifo.sby
```

This generates a lot of output. Among the plethora of text you should see the
lines

```
[one_stage_fifo_bmc] DONE (PASS, rc=0)
```

and

```
[one_stage_fifo_cover] DONE (PASS, rc=0)
```

This is it! We've now formally verified that the implementation of the one
stage fifo satisfies all the formal requirements.

## Next Step : A simple memory with a Wishbone interface
In order to gain more experience with formal verification I need to implement a
simple module. I chose a small memory with a Wishbone interface, so as to learn
about that bus protocol too.

The actual implementation of the memory is in the file
[wb_mem/wb_mem.v](wb_mem/wb_mem.v). There is a great introduction to the
wishbone bus protocol
[here](http://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html), and a
discussion of how to formally verify it
[here](http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html).  The author
provides a ready-to-use
[file](https://github.com/ZipCPU/zipcpu/blob/master/rtl/ex/fwb_slave.v) to
verify the wishbone protocol.

With the above, it is a simple matter to instantiate the module `fwb_slave`
within the file `wb_mem.v`.

There was one obstacle that caused me some problems: The following section in `wb_mem.v`

```
   // We have no more than a single outstanding request at any given time
   always @(posedge clk_i)
   if (wb_ack_o && wb_cyc_i)
      assert(f_outstanding == 1);
   else
      assert(f_outstanding == 0);
```

seems superfluous in that response always comes on the following clock cycle
anyway. However, removing these asserts caused the formal verification to fail.
I don't at the moment understand why this is the case.

Reading [this document](http://zipcpu.com/tutorial/class-vhdl.pdf) tells me
that using `mode prove` in the `wb_mem.sby` file works differently than `mode
bmc`.  With `mode prove` the tool tries to perform induction steps, and uses
`assert()` statements as prerequisites in the proof. Slides 94-96 in the
before-mentioned document describes this.

## VHDL
Getting formal verification to work in VHDL requires quite a lot of manual
setup and install; it would seem the tools are not quite as mature for VHDL.
Anyway, I managed to get it working in the end. The main components was [this
document](http://pepijndevos.nl/2019/08/15/open-source-formal-verification-in-vhdl.html)
describing how to install GHDL and related tools.

The first step is to install Yosys and the related solvers, see [this
link](https://symbiyosys.readthedocs.io/en/latest/install.html).

To use formal verification with VHDL, the actual design file is unchanged, but
the design must be instantiated in a Verilog file, where all the formal
verification is defined. And the SymbiYosys tools must be started with some
additional command line parameters.

### FETCH module of a yet-to-be-made CPU

Since I plan to write a pipelined CPU and formally verify it, I've chosen to
start with the instruction FETCH module. There is a [very detailed
discussion](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) about how to
write and formally verify such a module. The only difference is I'm writing the
module itself in VHDL.

So far I've made a simple implementation in [fetch/fetch.vhd](fetch/fetch.vhd).
This implementation is not optimized, but is purposefully kept simple, The
formal verification is written in verilog in the file
[fetch/fetch_vhd.sv](fetch/fetch_vhd.sv). This module just instantiates the
VHDL implementation, and then the remainder of the file contains the ASSUME,
ASSERT, and COVER statements that describe the properties used during formal
verification.

The last file to write is the yosys script file
[fetch/fetch.sby](fetch/fetch.sby). Note the use of ghdl to parse the VHDL
file, and that the "prep -top" line references the verilog module and not the
VHDL entity.

One more final thing to remember is how to actually run the formal
verification.  When working with VHDL files, the `sby` command needs additional
command line parameters. Therefore, it is easiest to write this command in a
Makefile. So running the test is a simple as typing `make`.

So far the formal verification only checks for one thing: The output to the
DECODE stage must not change, until it has been accepted. This actually fails
verification, which just shows that even such a simple statement is ambiguous.
And this proves a more general point: Unit testing and (formal) verification of
a module forces one to consider exactly how the interfaces are to work.

To get a better picture of what is happening, we can type `make show` to start
up `gtkwave` and display the waveform associated with the failure.  This shows
that particular failure here is because `dc_valid_i` is asserted when the FETCH
module is in `WAIT_RESP_ST` state.

Before we fix this particular issue, let's expand the formal verification file
`fetch_vhd.sv` with more assumptions. I'm here following closely [this
link](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html).

So now I've added all the assumptions, including adding the [WISHBONE MASTER
formal verification
file](https://github.com/ZipCPU/zipcpu/blob/master/rtl/ex/fwb_master.v).

Firing up again SymbiYosys (the formal verification tool) by typing `make`
shows that the module fails because `wb_ack_i` is asserted in the same clock
cycle that `wb_stb_o`.

Once again, we're faced with unclear requirements. Simply stating that the
FETCH module should only issue a signle transaction and should wait for a
response does not specify how to handle response that arrives combinatorially.
Should we even allow this? Well, it seems wrong to dis-allow it, since some
WISHBONE slaves may indeed respond combinatorially.

In other words, the formal verification quickly found a bug in my understanding
of the requirements, and I therefore need to change the implementation. After
some changes to the implementation I'm back at the first problem: The
verification fails because the signal `dc_valid_o` transitions from 1 to 0,
while `dc_ready_i` was 0. The problem here is I'm trying to abort an
instruction to the DECODE stage, but the formal verification was not written
correctly to reflect that fact.

I've therefore removed this particular assertion, and then gone back to [the
link from before]((http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) and
using that as inspiration for writing the assertions. And fixing some more bugs
at the same time.


