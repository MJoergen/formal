# FETCH module of a yet-to-be-made CPU

Since I plan to write a pipelined CPU and formally verify it, I've chosen to
start with the instruction FETCH module. There is a [very detailed
discussion](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) about how to
write and formally verify such a module. The only difference is I'm writing the
module itself in VHDL, and the requirements are slightly different. In particular,
this module is expected to have higher throughput.

## The interface
The idea is that this module has a wishbone interface to memory and another
interface towards the DECODE stage of the CPU. The DECODE stage accepts pairs
of (address, instruction) values, where the address increases by 1 every time.
Occasionally, the DECODE stage will request a new starting point, e.g. after a
branch instruction.

Going into more detail, the interface of this module can be broken into four
separate interfaces:
* Sending read requests to WISHBONE (with possible back-pressure)
   - `wb_cyc_o   : out std_logic;`
   - `wb_stb_o   : out std_logic;`
   - `wb_stall_i : in  std_logic;`
   - `wb_addr_o  : out std_logic_vector(15 downto 0);`
* Receiving read responses from WISHBONE
   - `wb_ack_i   : in  std_logic;`
   - `wb_data_i  : in  std_logic_vector(15 downto 0);`
* Sending instructions to DECODE stage (with possible back-pressure)
   - `dc_valid_o : out std_logic;`
   - `dc_ready_i : in  std_logic;`
   - `dc_addr_o  : out std_logic_vector(15 downto 0);`
   - `dc_inst_o  : out std_logic_vector(15 downto 0);`
* Receiving a new PC from DECODE
   - `dc_valid_i : in  std_logic;`
   - `dc_pc_i    : in  std_logic_vector(15 downto 0)`

The main point here is that there are two independent data streams into the
FETCH module (data read from WISHBONE and new PC value from the DECODE), and
these two data streams don't support back-pressure. So the FETCH module must at
any time be ready to accept data on these two interfaces, possibly even
simultaneously.

Furthermore, the two outgoing interfaces both support back-pressure. The main
complication here is that we may receive data from the WISHBONE but not be able
to send the data to the DECODE stage. The [simple
version](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) solved this
problem but not issuing any new WISHBONE request until the DECODE stage had
accepted the current data. This simplifies the design, at the cose of
performance, so I will try to do it better.

## Formal verification
Rather than discussing the implementation, let's dive straight into the formal
verification.

As before I have the obvious requirement that we start in reset. This requirement
is needed by the BMC in order to make sure we start in a valid state.

```
initial `ASSUME(rst_i);
```

Verifying the WISHBONE transactions is as easy as instantiating the
[fwb_master](https://github.com/ZipCPU/zipcpu/blob/master/rtl/ex/fwb_master.v)
module.

We have to be careful selecting the correct paramters. Here I've chosen:
* `.F_MAX_STALL          (4)`. This prevents the WISHBONE slave from stalling
  forever. This is needed for the formal verification.
* `.F_OPT_SOURCE         (1)`. This adds extra checks to the interface.
* `.F_OPT_RMW_BUS_OPTION (0)`. We require CYC to go low when there are no
  outstanding requests.
* `.F_OPT_DISCONTINUOUS  (1)`. We allow multiple requests in the same bus
  transactions.

Now, the above is not quite enough for the formal prover. Some more logic is
needed to constrain the allowable states. The following code re-states that we
can have at most one outstanding transaction at any time. The formal prover can
verify the correctness of this assertion, and subsequenly use this is the
induction step.

```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(wb_cyc_o) && $past(wb_ack_i))
      assert (f_outstanding == 0);
   assert(f_outstanding <= 1);
end
```

Next follows all the assertions about the interface towards to DECODE stage. The
first is the assertion that the output to the DECODE stage should be kept
stable until it has been accepted or until a new address request has been issued.

```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(!rst_i) && $past(!dc_valid_i) && $past(dc_valid_o) && $past(!dc_ready_i))
   begin
      assert ($stable(dc_valid_o));
      assert ($stable(dc_addr_o));
      assert ($stable(dc_inst_o));
   end
end
```


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


