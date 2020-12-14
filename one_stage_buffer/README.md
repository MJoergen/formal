# Another simple module : One Stage Buffer
This module is very similar to the [../one_stage_fifo](one_stage_fifo) we just
completed.  In particular, the port signals are the same as for
`one_stage_fifo`, but the functionality is slightly different.

The requirements here are that this buffer works as a combinatorial wire
between the sender and the receiver.  If the receiver is not ready, then this
module will store the data for later.

This module is useful e.g. in situations where the sender does not support
back-pressure.

