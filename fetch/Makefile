DUT = fetch

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_prove:
	gtkwave $(DUT)_prove/engine_0/trace_induct.vcd $(DUT).gtkw

show_cover0:
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw

show_cover1:
	gtkwave $(DUT)_cover/engine_0/trace1.vcd $(DUT).gtkw

show_cover2:
	gtkwave $(DUT)_cover/engine_0/trace2.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/

