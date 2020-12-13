DUT = fetch

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)/engine_0/trace.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/

