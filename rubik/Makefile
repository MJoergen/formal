DUT = rubik

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover:
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf work-obj93.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif

# Synthesis

work-obj93.cf: $(DUT).vhd
	ghdl -a $^

synth: work-obj93.cf
	yosys -m ghdl -p 'ghdl $(DUT); synth_xilinx -top $(DUT) -edif $(DUT).edif' > yosys.log


