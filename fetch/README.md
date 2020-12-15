# FETCH module of a yet-to-be-made CPU

Since I plan to write a pipelined CPU and formally verify it, I've chosen to
start with the instruction FETCH module. There is a [very detailed
discussion](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) about how to
write and formally verify such a module. The only difference is I'm writing the
module itself in VHDL, and the requirements are slightly different. In
particular, this module is expected to have higher throughput, i.e. potentially
able to deliver a new instruction on every clock cycle.

## The interface
The idea is that this module has a WISHBONE interface to e.g. a memory and
another interface towards the DECODE stage of the CPU. The DECODE stage accepts
pairs of (address, data) values, where the address increases by 1 every time.
Additionally, the DECODE stage may request a new starting point, e.g.  after a
branch instruction.

Being more specific, the interface of this module can be broken into four
separate interfaces:
* Sending read requests to WISHBONE (with possible back-pressure)
```
      wb_cyc_o   : out std_logic;
      wb_stb_o   : out std_logic;
      wb_stall_i : in  std_logic;
      wb_addr_o  : out std_logic_vector(15 downto 0);
```
* Receiving read responses from WISHBONE
```
      wb_ack_i   : in  std_logic;
      wb_data_i  : in  std_logic_vector(15 downto 0);
```
* Sending instructions to DECODE stage (with possible back-pressure)
```
      dc_valid_o : out std_logic;
      dc_ready_i : in  std_logic;
      dc_addr_o  : out std_logic_vector(15 downto 0);
      dc_data_o  : out std_logic_vector(15 downto 0);
```
* Receiving a new PC from DECODE
```
      dc_valid_i : in  std_logic;
      dc_addr_i  : in  std_logic_vector(15 downto 0);
```

The main point here is that there are two independent data streams into the
FETCH module (data read from WISHBONE and new PC value from the DECODE), and
these two data streams don't support back-pressure. So the FETCH module must at
any time be ready to accept data on these two interfaces, possibly even
simultaneously.

Furthermore, the two outgoing interfaces both support back-pressure. The main
complication here is that we may receive data from the WISHBONE but not be able
to send the data to the DECODE stage. The [simple
version](http://zipcpu.com/zipcpu/2017/11/18/wb-prefetch.html) solved this
problem by not issuing any new WISHBONE request until the DECODE stage had
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
      assert ($stable(dc_data_o));
   end
end
```

The above verifies the control signals, but we're not done yet. We need to
verify that the correct address and data signals are forwarded to the DECODE.
The main property is that the forward address increments by one every time,
until a new PC is received from the DECODE stage. So we add some lines
to keep track of the last valid address sent to the DECODE stage:

```
reg f_last_pc_valid;
reg [15:0] f_last_pc;
initial f_last_pc_valid = 1'b0;
initial f_last_pc = 16'h0000;
always @(posedge clk_i)
begin
   if (dc_valid_o)
   begin
      f_last_pc_valid <= 1'b1;
      f_last_pc <= dc_addr_o;
   end
   if (rst_i || dc_valid_i)
   begin
      f_last_pc_valid <= 1'b0;
   end
end
```

Then we can check whether addresses increment as expected:

```
always @(posedge clk_i)
begin
   if (f_past_valid && dc_valid_o && f_last_pc_valid && $past(dc_ready_i))
   begin
      assert (dc_addr_o == f_last_pc + 1'b1);
   end
end
```

Oops! Adding this check uncovered a bug in the implementation so far. I fixed this bug by
making use of the `one_stage_buffer` module. However, that still did not work, because
there was an error in the `one_stage_buffer module`, **despite its formal verification**!
So I first had to extend the formal verification of that module to verify the bug, and
then fix the bug, and re-run formal verification. Then I could return to this module.


