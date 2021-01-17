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
SOURCES += system.vhd
TB_SOURCES += ../wb_mem/wb_mem.vhd
TB_SOURCES += tb_cpu.vhd
TB   = tb_cpu
WAVE = $(TB).ghw
SAVE = $(TB).gtkw
ROM  = prog.rom

ASSEMBLER = /home/mike/git/sy2002/QNICE-FPGA/assembler/asm

$(WAVE): $(SOURCES) $(TB_SOURCES) $(ROM)
	ghdl -i --std=08 $(SOURCES) $(TB_SOURCES)
	ghdl -m --std=08 $(TB)
	ghdl -r --std=08 $(TB) --wave=$(WAVE) --stop-time=1us
	gtkwave $(WAVE) $(SAVE)

test%:
	$(ASSEMBLER) $@.asm
	mv $@.rom $(ROM)
	make $(WAVE)

clean:
	rm -rf test1.lis
	rm -rf test1.out
	rm -rf work-obj08.cf
	rm -rf $(WAVE)
	rm -rf $(ROM)

