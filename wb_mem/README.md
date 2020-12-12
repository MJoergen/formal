# A simple memory with a Wishbone interface
In order to gain more experience with formal verification I've decided to
implement another simple module. I chose a small memory with a Wishbone
interface, so as to learn about that bus protocol too.

The actual implementation of the memory is in the file
[wb_mem.vhd](wb_mem.vhd). There is a great introduction to the
wishbone bus protocol
[here](http://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html), and a
discussion of how to formally verify it
[here](http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html).  The author
provides a ready-to-use
[file](https://github.com/ZipCPU/zipcpu/blob/master/rtl/ex/fwb_slave.v) to
verify the wishbone protocol.

With the above, it is a simple matter to instantiate the module `fwb_slave`
within the file `wb_mem_formal.sv`.

