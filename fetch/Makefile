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

show_cover5:
	gtkwave $(DUT)_cover/engine_0/trace5.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/
	rm -rf work-obj93.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif

# Synthesis

work-obj93.cf: ../one_stage_buffer/one_stage_buffer.vhd $(DUT).vhd
	ghdl -a $^

synth: work-obj93.cf
	yosys -m ghdl -p 'ghdl $(DUT); synth_xilinx -top $(DUT) -edif $(DUT).edif' > yosys.log


