# Formal verification

Others have gone here before me, and now it is my turn!

[Formal verification](http://zipcpu.com/formal/formal.html) is a tool for
verifying the correctness of your implementation. Traditional verification
strategies have relied on hand-crafted testbenches to provide stimuli to the
DUT.  Formal verification aims to automate that process. In my view the two
approaches (testbench and formal) supplement each other, rather than replace
each other.

## Installing the tools
I've written a [separate document](INSTALL.md) with a guide on how to install
all the necessary tools.

## Doing formal verification in VHDL
To use formal verification with VHDL, the actual design file is unchanged, but
the design must be instantiated inside a Verilog file, where all the formal
verification is defined. And the SymbiYosys tools must be started with some
additional command line parameters. This is demonstrated in the below examples.

## Example designs using formal verification
* [One Stage Fifo](one_stage_fifo/). This is a kind of "hello world" of formal verification.
* [Wishbone memory](wb_mem/). This is to learn about the wishbone bus protocol.
* [Fetch](fetch/). The first "real" module. This is a simple instruction fetch module for a CPU.

