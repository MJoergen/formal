# Type 'make formal' to run formal verification
# Type 'make synth' to run synthesis

DUT  = axi_fifo
SRC += $(DUT).vhd


#######################
# Formal verification
#######################

.PHONY: formal
formal: $(DUT)_cover/PASS $(DUT)_prove/PASS
$(DUT)_cover/PASS: $(DUT).sby $(DUT).psl $(SRC)
	# This is the main command line to run the formal verification
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_prove:
	gtkwave $(DUT)_prove/engine_0/trace_induct.vcd $(DUT).gtkw


#######################
# Cleanup
#######################

.PHONY: clean
clean:
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/
	rm -rf work-obj08.cf

