SOURCES += cpu_constants.vhd
SOURCES += ../two_stage_fifo/two_stage_fifo.vhd
SOURCES += ../one_stage_buffer/one_stage_buffer.vhd
SOURCES += ../two_stage_buffer/two_stage_buffer.vhd
SOURCES += ../pipe_concat/pipe_concat.vhd
SOURCES += ../fetch2/fetch.vhd
SOURCES += alu.vhd
SOURCES += decode.vhd
SOURCES += execute.vhd
SOURCES += registers.vhd
SOURCES += cpu.vhd
TB_SOURCES += ../wb_mem/wb_mem.vhd
TB_SOURCES += tb_cpu.vhd

all: $(SOURCES) $(TB_SOURCES)
	ghdl -a --std=08 -frelaxed $^
