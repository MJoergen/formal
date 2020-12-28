DUT = rubik

# This is the main command line to run the formal verification
all:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover0:
	gtkwave $(DUT)_cover/engine_0/trace0.vcd $(DUT).gtkw

show_cover1:
	gtkwave $(DUT)_cover/engine_0/trace1.vcd $(DUT).gtkw

clean:
	rm -rf $(DUT)_bmc/
	rm -rf $(DUT)_cover/
	rm -rf work-obj08.cf
	rm -rf yosys.log
	rm -rf $(DUT).edif
	rm -rf $(DUT).ghw

# Synthesis

work-obj08.cf: $(DUT).vhd
	ghdl -a -fpsl -fsynopsys --std=08 $^

synth: work-obj08.cf
	yosys -m ghdl -p 'ghdl -fpsl -fsynopsys --std=08 $(DUT); synth_xilinx -top $(DUT) -edif $(DUT).edif' > yosys.log

# Simulation

sim: $(DUT).vhd $(DUT)_tb.vhd
	ghdl -i -fpsl --std=08 --work=work $^
	ghdl -m -fpsl --std=08 --ieee=synopsys -fexplicit $(DUT)_tb
	ghdl -r -fpsl --std=08 --ieee=synopsys $(DUT)_tb --wave=$(DUT).ghw --stop-time=4us
	gtkwave $(DUT).ghw $(DUT)_sim.gtkw

