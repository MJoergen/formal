# Available make targets:
# 'make' runs the simulation
# 'make system.bit' runs Vivado synthesis and bitfile generation
# 'make synth' runs Yosys synthesis

XILINX_DIR = /opt/Xilinx/Vivado/2019.2

SOURCES += axi_pause.vhd
SOURCES += cpu_constants.vhd
SOURCES += ../one_stage_fifo/one_stage_fifo.vhd
SOURCES += ../two_stage_fifo/two_stage_fifo.vhd
SOURCES += ../one_stage_buffer/one_stage_buffer.vhd
SOURCES += ../two_stage_buffer/two_stage_buffer.vhd
SOURCES += ../pipe_concat/pipe_concat.vhd
SOURCES += ../fetch2/fetch.vhd
SOURCES += ../memory/memory.vhd
SOURCES += alu_data.vhd
SOURCES += alu_flags.vhd
SOURCES += microcode.vhd
SOURCES += decode.vhd
SOURCES += execute.vhd
SOURCES += dp_ram.vhd
SOURCES += registers.vhd
SOURCES += cpu.vhd
SOURCES += ../wb_tdp_mem/tdp_ram.vhd
SOURCES += ../wb_tdp_mem/wb_tdp_mem.vhd
SOURCES += system.vhd
TOP = system

ASM  = prog.asm
ROM  = prog.rom

TB      = tb_cpu
TB_SRC += $(TB).vhd
WAVE    = $(TB).ghw
SAVE    = $(TB).gtkw

ASSEMBLER = $(HOME)/git/sy2002/QNICE-FPGA/assembler/asm

show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)

$(WAVE): $(SOURCES) $(TB_SRC) $(ROM)
	ghdl -i --std=08 $(SOURCES) $(TB_SRC)
	ghdl -m --std=08 -frelaxed $(TB)
	ghdl -r --std=08 -frelaxed $(TB) --wave=$(WAVE) --stop-time=300us

$(ROM): $(ASM)
	$(ASSEMBLER) $(ASM)

$(TOP).bit: $(TOP).tcl $(SOURCES) $(TOP).xdc $(ROM)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

$(TOP).tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(SOURCES)  }" >> $@
	echo "read_xdc $(TOP).xdc" >> $@
	echo "synth_design -top $(TOP) -part xc7a100tcsg324-1 -flatten_hierarchy none" >> $@
	echo "write_checkpoint -force post_synth.dcp" >> $@
	echo "opt_design -directive NoBramPowerOpt" >> $@
	echo "place_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force post_route.dcp" >> $@
	echo "write_bitstream -force $(TOP).bit" >> $@
	echo "exit" >> $@

synth: $(SOURCES) $(ROM)
	ghdl -a --std=08 -frelaxed $(SOURCES)
	yosys -m ghdl -p 'ghdl --std=08 -frelaxed $(TOP); synth_xilinx -top $(TOP) -edif $(TOP).edif' > yosys.log

clean:
	rm -rf prog.lis
	rm -rf prog.out
	rm -rf work-obj08.cf
	rm -rf $(WAVE)
	rm -rf $(ROM)
	rm -rf yosys.log
	rm -rf $(TOP).tcl
	rm -rf post_synth.dcp
	rm -rf post_route.dcp
	rm -rf $(TOP).bit
	rm -rf vivado*
	rm -rf usage_statistics_webtalk*
	rm -rf tight_setup_hold_pins.txt
	rm -rf system.edif

