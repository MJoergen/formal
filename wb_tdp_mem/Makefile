DUT = wb_tdp_mem

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover:
	gtkwave $(DUT)_cover/engine_0/trace3.vcd $(DUT).gtkw

show_prove:
	gtkwave $(DUT)_prove/engine_0/trace_induct.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/
	rm -rf work-obj08.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif

# Synthesis

work-obj08.cf: $(DUT).vhd
	ghdl -a -fpsl --std=08 $^

synth: work-obj08.cf
	yosys -m ghdl -p 'ghdl -fpsl --std=08 $(DUT); synth_xilinx -top $(DUT) -family xc7 -edif $(DUT).edif' > yosys.log

