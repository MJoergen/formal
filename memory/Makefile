DUT = memory

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover2:
	gtkwave $(DUT)_cover/engine_0/trace2.vcd $(DUT).gtkw

show_cover3:
	gtkwave $(DUT)_cover/engine_0/trace3.vcd $(DUT).gtkw

show_cover4:
	gtkwave $(DUT)_cover/engine_0/trace4.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf $(DUT)_prove/
	rm -rf work-obj08.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif

# Synthesis

SOURCES += ../one_stage_buffer/one_stage_buffer.vhd
SOURCES += ../one_stage_fifo/one_stage_fifo.vhd
SOURCES += $(DUT).vhd

work-obj08.cf: $(SOURCES)
	ghdl -a -fpsl -fsynopsys --std=08 $^

synth: work-obj08.cf
	yosys -m ghdl -p 'ghdl -fpsl -fsynopsys --std=08 $(DUT); synth_xilinx -top $(DUT) -edif $(DUT).edif' > yosys.log


