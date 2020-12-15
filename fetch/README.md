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
verification. The idea is to come up with just the right set of requirements
needed to formally prove the correctness of the implementation.

### WISHBONE interface
Let's begin with verifying the WISHBONE transactions. This is as easy as
instantiating the
[fwb_master](https://github.com/ZipCPU/zipcpu/blob/master/rtl/ex/fwb_master.v)
module.

We have to be careful selecting the correct paramters. Here I've chosen the
following values:
```
F_MAX_STALL          = 3. This prevents the WISHBONE slave from stalling forever. This is needed for the formal verification.
F_MAX_ACK_DELAY      = 3. This
F_OPT_SOURCE         = 1. This adds extra checks to the interface.
F_OPT_RMW_BUS_OPTION = 0. We require CYC to go low when there are no outstanding requests.
F_OPT_DISCONTINUOUS  = 1. We allow multiple requests in the same bus transactions.
```

Here `F_MAX_STALL` and `F_MAX_ACK_DELAY` are artificial values chosen to put an
upper bound on the duration of the proof. They are needed to prevent the design
from waiting indefinitely for input. The remaining parameters control the
detailed behaviour of the design. Together they state the requirement that the
FETCH module may issue several requests within the same transaction, and that
the transaction must end when no more requests.

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
   assert (f_outstanding <= 1);
end
```

### Assumptions about inputs
We now turn our attention to our inputs.  First of all let's require that we
start in reset. This requirement is needed by the BMC in order to make sure we
start in a valid state.

```
initial `ASSUME(rst_i);
```

Next we impose the artifical requirement that the DECODE stage sends a new PC
right after reset. This is again needed by the BMC.

```
always @(posedge clk_i)
begin
   if (f_past_valid && $past(rst_i))
      assume (dc_valid_i);
end
```

And similar to the WISHBONE interface, we pose the artifical requirement that
the DECODE stage does not stall indefinitely. So first we add some code to count
the length of the current stall:

```
reg [1:0] f_dc_wait_count;
initial f_dc_wait_count = 2'b0;
always @(posedge clk_i)
begin
   if (dc_valid_o && ~dc_ready_i)
      f_dc_wait_count <= f_dc_wait_count + 2'b1;
   else
      f_dc_wait_count <= 2'b0;

   if (rst_i)
   begin
      f_dc_wait_count <= 2'b0;
   end
end
```

And then we impose the requirement as follows:

```
always @(posedge clk_i)
begin
   assume (f_dc_wait_count < 3);
end
```

Finally, we will place some additional requirements on the data inputs from the
WISHBONE, in order to be able to recognize the same data on the output to the
DECODE stage. Here I simply choose the data signal to be the inverse of the
address signal:

```
always @(posedge clk_i)
begin
   if (wb_cyc_o && wb_ack_i)
   begin
      assume (wb_data_i == ~wb_addr_o);
   end 
end
```


### Assertions about outputs
We now get to the requirements. Let's just quickly deal with the data signal that
we just constrained on the WISHBONE input. With this constraint we can assert
the same relationship on the data presented to the DECODE stage:

```
always @(posedge clk_i)
begin
   if (dc_valid_o)
   begin
      assert (dc_data_o == ~dc_addr_o);
   end
end
```

Now, recall that the FETCH module should read sequential addresses from the
WISHBONE bus and present to the DECODE stage.

So let's write code to check the WISHBONE addresses being requested.  The
following code calculates the next address we expect to see on the WISHBONE
bus:

```
reg [15:0] f_req_addr;
initial f_req_addr = 16'h0000;
always @(posedge clk_i)
begin
   if (dc_valid_i)
   begin
      // New PC received from DECODE
      f_req_addr <= dc_addr_i;
   end
   else if (wb_cyc_o && wb_ack_i)
   begin
      // ACK received from WISHBONE
      f_req_addr <= f_req_addr + 1'b1;
   end
end
```

And then we can do the actual verification here:

```
always @(posedge clk_i)
begin
   if (wb_cyc_o && wb_stb_o)
   begin
      assert (f_req_addr == wb_addr_o);
   end
end
```

We do something similar for the addresses presented on the DECODE bus.
First we record the last valid address sent to the DECODE stage:

```
reg f_last_addr_valid;
reg [15:0] f_last_addr;
initial f_last_addr_valid = 1'b0;
initial f_last_addr = 16'h0000;
always @(posedge clk_i)
begin
   if (dc_valid_o)
   begin
      f_last_addr_valid <= 1'b1;
      f_last_addr <= dc_addr_o;
   end
   if (rst_i || dc_valid_i)
   begin
      f_last_addr_valid <= 1'b0;
   end
end
```

Now we validate that the address on the DECODE bus is one more than the
previous address.

```
always @(posedge clk_i)
begin
   if (f_past_valid && dc_valid_o && f_last_addr_valid && $past(dc_ready_i))
   begin
      assert (dc_addr_o == f_last_addr + 1'b1);
   end
end
```

In order to constrain the formal prover sufficiently, we need to add one more
assertion: That the address requested on the WISHBONE bus is one more that the
address presented on the DECODE stage. This is not an assumption, this is an
assertion. I.e. it is a claim that the formal verifier will check. And
subsequently the prover will use to complete the k-induction formal proof.

```
always @(posedge clk_i)
begin
   if (f_past_valid && dc_valid_o && $past(dc_ready_i))
   begin
      assert (f_req_addr == dc_addr_o + 1'b1);
   end
end
```

We have one final assertion:  The output to the DECODE stage should be kept
stable until it has been accepted or until a new address request has been
issued.

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

### Cover statements

As a final step I thought it would be interesting with some specific cover
statements.  The first one is that the DECODE stage accepts data. This is seen
by the `dc_valid_o` signal going from high to low:

```
always @(posedge clk_i)
begin
   cover (f_past_valid && !rst_i && $past(dc_valid_o) && !dc_valid_o);
end
```

The second cover statement is that the DECODE stage can receive to data cycles
back-to-back, i.e. with `dc_valid_o` and `dc_ready_i` asserted for two clock
cycles. After all, this was my initial claim.

```
always @(posedge clk_i)
begin
   cover (f_past_valid && $past(dc_valid_o) && $past(dc_ready_i) && dc_valid_o);
end
```

And that is it for the formal verification!

## Implementation details
One difficulty I had when implementing is that when we send a WISHBONE request
for the next address, but the DECODE stage has not yet accepted the current
address. This becomes a problem when we receive the response from the
WISHBONE bus, and we have no-where to store the result.

The solution was to make use of the `one_stage_buffer`.

However, I do see problems with formally verifying hierarchical designs in
VHDL.  Because the `one_stage_buffer` has some associated properties, but so
far I've not yet found a way to make use of them when verifyinf the FETCH
module. This would not be a problem if all source files were written in
Verilog.

## Synthesis report
I've added a `make` target to use yosys to generate a synthesis report. Just type `make synth`. I get
the following result:

```
   Number of cells:                238
     BUFG                            1
     CARRY4                          4
     FDRE                           84
     IBUF                           38
     INV                             1
     LUT2                            2
     LUT3                           36
     LUT4                            1
     LUT6                           19
     MUXF7                           1
     OBUF                           51

   Estimated number of LCs:         56
```

So an estimated 56 LUTs and 84 registers to implement this FETCH module.

