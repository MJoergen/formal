SOURCES += axi_pause.vhd
SOURCES += cpu_constants.vhd
SOURCES += ../two_stage_fifo/two_stage_fifo.vhd
SOURCES += ../one_stage_buffer/one_stage_buffer.vhd
SOURCES += ../two_stage_buffer/two_stage_buffer.vhd
SOURCES += ../pipe_concat/pipe_concat.vhd
SOURCES += ../fetch2/fetch.vhd
SOURCES += alu.vhd
SOURCES += microcode.vhd
SOURCES += decode.vhd
SOURCES += execute.vhd
SOURCES += registers.vhd
SOURCES += cpu.vhd
SOURCES += ../wb_mem/wb_mem.vhd
SOURCES += system.vhd
TOP = system

ASM  = prog.asm
ROM  = prog.rom

TB      = tb_cpu
TB_SRC += $(TB).vhd
WAVE    = $(TB).ghw
SAVE    = $(TB).gtkw

ASSEMBLER = /home/mike/git/sy2002/QNICE-FPGA/assembler/asm

$(WAVE): $(SOURCES) $(TB_SRC) $(ROM)
	ghdl -i --std=08 $(SOURCES) $(TB_SRC)
	ghdl -m --std=08 $(TB)
	ghdl -r --std=08 $(TB) --wave=$(WAVE) --stop-time=1us
	gtkwave $(WAVE) $(SAVE)

$(ROM): $(ASM)
	$(ASSEMBLER) $(ASM)

synth: $(SOURCES) $(ROM)
	ghdl -a --std=08 $(SOURCES)
	yosys -m ghdl -p 'ghdl --std=08 $(TOP); synth_xilinx -top $(TOP) -edif $(TOP).edif' > yosys.log

clean:
	rm -rf prog.lis
	rm -rf prog.out
	rm -rf work-obj08.cf
	rm -rf $(WAVE)
	rm -rf $(ROM)
	rm -rf yosys.log

