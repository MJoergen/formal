# Formal verification

Others have gone here before me, and now it is my turn!

[Formal verification](http://zipcpu.com/formal/formal.html) is a tool for
verifying the correctness of your implementation. Traditional verification
strategies have relied on hand-crafted testbenches to provide stimuli to the
DUT.  Formal verification aims to automate that process. In my view these two
approaches (testbench and formal) supplement each other, rather than replace
each other.

## Installing the tools
I've written a [separate document](INSTALL.md) with a guide on how to install
all the necessary tools.

## Doing formal verification in VHDL
To use formal verification with VHDL, we need to learn [a new language
PSL](http://www.project-veripage.com/psl_tutorial_1.php). The VHDL file is
augmented with verification commands like `assert`, `assume`, and `cover`.
Furthermore, the SymbiYosys tools must be started with some additional command
line parameters.  This is demonstrated in the below examples.

## Example designs using formal verification
* [One Stage Fifo](one_stage_fifo/). This is a kind of "hello world" of formal verification.
* [One Stage Buffer](one_stage_buffer/). Another simple but useful module.
* [Two Stage Fifo](two_stage_fifo/). Small FIFO useful for timing closure.
* [Two Stage Buffer](two_stage_buffer/). Small FIFO useful for timing closure.
* [Pipe_Concat](pipe_concat/). Concatenate two elastic pipe streams.
* [Wishbone memory](wb_mem/). This is to learn about the wishbone bus protocol.
* [Fetch](fetch/). The first "real" module. This is a simple instruction fetch module for a CPU.
* [Fetch2](fetch2/). A second (more optimized) implementation of the instruction fetch module.

## Example puzzles using formal verification
* [Fox, Goat, and Cabbage](fgc). This uses formal verification to solve a well-known puzzle.
* [Rubik's 2x2x2](rubik). This uses formal verification to solve Rubik's 2x2x2 cube.

## Other resources
* [This video](https://www.youtube.com/watch?v=H3tsP9tjYdY) gives a nice
  introduction to formal verification, including a lot of small and easy
  examples.

* [This video-series](https://www.youtube.com/watch?v=_5R35QFsXM4) gives a more
  detailed tutorial for getting started with formal verification.

* [Robert Baruch](https://www.youtube.com/watch?v=85ZCTuekjGA) has made a video
  series on building a 6800 CPU using
  [nMigen](https://github.com/nmigen/nmigen) and applying formal verification
  in the process. This was the first time I heard about formal verification, and
  has been a great inspiration for me.

* [Charles LaForest](http://fpgacpu.ca/fpga/index.html) has compiled a huge
  resource on VHDL design elements. There is no formal verification, but this
  website is a good resource, with detailed explanation of each module.

