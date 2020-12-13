DUT = fgc

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show:
	gtkwave $(DUT)/engine_0/trace0.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)/

