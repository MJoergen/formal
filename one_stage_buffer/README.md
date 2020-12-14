# Another simple module : One Stage Buffer
This module is very similar to the [../one_stage_fifo](one_stage_fifo) we just
completed.  In particular, the port signals are the same as for
`one_stage_fifo`, but the functionality is slightly different.

The requirements here are that this buffer works as a combinatorial wire
between the sender and the receiver.  If the receiver is not ready, then this
module will store the data for later.

This module is useful e.g. in situations where the sender does not support
back-pressure.

## A bugfix
Even though this module appears simple, I found a bug in it, while verifying
the FETCH module! So let's first explain the bug. The problem is that sometimes
data would get lost. I.e. the `m_valid_o` signal was not asserted. This could
happen if the first data input got registered internally, and when this value
was sent out a new value simultaneously was received. This new value was never
forwarded.

Before solving this bug we clearly have a problem in our formal verification,
so let's fix that first. Because so far, we have only verified the handshake,
not the actual data forwarded. To do this, we need to keep a count of amount
of data received and sent, as well as the last data received.

This is all done in the following lines:

```
reg [G_DATA_SIZE-1:0] f_last_value;
reg [1:0] f_count;
initial f_last_value = 0;
initial f_count = 2'b0;
always @(posedge clk_i)
begin
   if (s_valid_i && s_ready_o)
   begin
      f_last_value <= s_data_i;
   end

   if (s_valid_i && s_ready_o && !(m_valid_o && m_ready_i))
   begin
      f_count <= f_count + 1'b1;
   end

   if (m_valid_o && m_ready_i && !(s_valid_i && s_ready_o))
   begin
      f_count <= f_count - 1'b1;
   end

   if (rst_i)
   begin
      f_count <= 2'b0;
   end
end
```

Now it's time for some assertions. First we constrain the count of outstanding
data:

```
always @(posedge clk_i)
begin
   if (s_valid_i && s_ready_o && m_valid_o && !m_ready_i)
      assert (f_count == 0);
   if (m_valid_o && m_ready_i && !s_valid_i && s_ready_o)
      assert (f_count == 1);
   assert (f_count <= 1);
end
```

Finally we can assert that the last data receive is also the data forwarded:

```
always @(posedge clk_i)
begin
   if (f_count && !rst_i)
   begin
      assert (m_data_o == f_last_value);
      assert (m_valid_o);
   end
end
```

With these changes, the formal verification now correctly identifies the
problem, and we can proceed to fix the bug.

