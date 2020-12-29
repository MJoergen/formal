# A simple memory with a Wishbone interface
In order to gain more experience with formal verification I've decided to
implement another simple module. I chose a small memory with a Wishbone
slave interface, so as to learn about that bus protocol too.

## Wishbone slave requirements
This wishbone memory module has a number of easy-to-test requirements:

When `wb_ack_o` is de-asserted, then `wb_data_o` is all zeros.
```
f_data_zero : assert always {not wb_ack_o} |-> {or(wb_data_o) = '0'};
```

When writing to memory, the data output is unchanged.
```
f_data_stable : assert always {wb_cyc_i and wb_stb_i and wb_we_i and not rst_i} |=> {stable(wb_data_o)};
```

The response always appears on the exact following clock cycle, i.e. a fixed latency of 1.
```
f_ack_next : assert always {wb_cyc_i and wb_stb_i and wb_we_i and not rst_i} |=> {wb_ack_o};
```

No ACKs allowed when the bus is idle.
```
f_ack_idle : assert always {not (wb_cyc_i and wb_stb_i)} |=> {not wb_ack_o};
```

At most one outstanding request.
```
f_outstanding : assert always {0 <= f_count and f_count <= 1};
```
Here I additionally need to keep a track of the number of outstanding requests as follows:
```
p_count : process (clk_i)
begin
   if rising_edge(clk_i) then
      -- Request without response
      if wb_cyc_i and wb_stb_i and not (wb_ack_o) then
         f_count <= f_count + 1;
      end if;

      -- Reponse without request
      if not(wb_cyc_i and wb_stb_i) and wb_ack_o then
         f_count <= f_count - 1;
      end if;

      if rst_i or not wb_cyc_i then
         f_count <= 0;
      end if;
   end if;
end process p_count;
```

No ACK without outstanding request
```
f_count_0 : assert always {f_count = 0} |-> {not wb_ack_o};
```

ACK always comes immediately after an outstanding request
```
f_count_1 : assert always {f_count = 1} |-> {wb_ack_o};
```

Low CYC aborts all transactions
```
f_idle : assert always {not wb_cyc_i} |=> {f_count = 0};
```

