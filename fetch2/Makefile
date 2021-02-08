# Type 'make formal' to run formal verification
# Type 'make synth' to run synthesis

DUT  = fetch
SRC += ../pipe_concat/pipe_concat.vhd
SRC += ../one_stage_buffer/one_stage_buffer.vhd
SRC += ../two_stage_buffer/two_stage_buffer.vhd
SRC += ../two_stage_fifo/two_stage_fifo.vhd
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
# Synthesis
#######################

.PHONY: synth
synth: work-obj08.cf
	yosys -m ghdl -p 'ghdl -fpsl -fsynopsys --std=08 $(DUT); synth_xilinx -top $(DUT) -edif $(DUT).edif' > yosys.log

work-obj08.cf: $(SRC)
	ghdl -a -fpsl -fsynopsys --std=08 $^


#######################
# Cleanup
#######################

.PHONY: clean
clean:
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/
	rm -rf work-obj08.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif

