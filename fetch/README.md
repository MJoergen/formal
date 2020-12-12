# FETCH module of a yet-to-be-made CPU

Since I plan to write a pipelined CPU and formally verify it, I've chosen to
start with the instruction FETCH module. There is a [very detailed
discussion](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) about how to
write and formally verify such a module. The only difference is I'm writing the
module itself in VHDL.

So far I've made a simple implementation in [fetch.vhd](fetch.vhd).  This
implementation is not optimized, but is purposefully kept simple.

In the first iteration the formal verification only checks for one thing: The
output to the DECODE stage must not change, until it has been accepted. This
actually fails verification, which just shows that even such a simple statement
is ambiguous.  And this proves a more general point: Unit testing and (formal)
verification of a module forces one to consider exactly how the interfaces are
to work.

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
FETCH module should only issue a single transaction and should wait for a
response does not specify how to handle responses that arrive combinatorially.
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
link from before](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) and
using that as inspiration for writing the assertions. And fixing some more bugs
at the same time.


