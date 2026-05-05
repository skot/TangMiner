TARGET ?= tangnano20k

ifeq ($(TARGET),tangnano9k)
BOARD := tangnano9k
FAMILY := GW1N-9C
DEVICE := GW1NR-LV9QN88PC6/I5
CST := constr/tangnano9k.cst
else ifeq ($(TARGET),tangnano20k)
BOARD := tangnano20k
FAMILY := GW2A-18C
DEVICE := GW2AR-LV18QN88C8/I7
CST := constr/tangnano20k.cst
else
$(error Unsupported TARGET '$(TARGET)'. Use tangnano20k or tangnano9k)
endif

TOP := top
BUILD := build
SRC := src/top.v src/uart_rx.v src/uart_tx.v src/bitcoin_hash_core.v src/sha256_compress.v
SPINAL_SRC := $(BUILD)/spinal/top.v
SPINAL_PREFIX := $(BUILD)/tangminer_spinal_$(TARGET)
VERILOG_PREFIX := $(BUILD)/tangminer_verilog_$(TARGET)
OSS_CAD_SUITE ?= $(HOME)/oss-cad-suite
TOOLBIN := $(OSS_CAD_SUITE)/bin
YOSYS := $(TOOLBIN)/yosys
NEXTPNR := $(TOOLBIN)/nextpnr-himbaechel
GOWIN_PACK := $(TOOLBIN)/gowin_pack
OPENFPGALOADER := $(TOOLBIN)/openFPGALoader
IVERILOG := $(TOOLBIN)/iverilog
VVP := $(TOOLBIN)/vvp
SBT ?= sbt

.PHONY: all build build-verilog spinal-verilog build-spinal load load-verilog load-spinal flash flash-verilog flash-spinal clean sim sim-sha sim-bitcoin

all: build

build: build-spinal

build-verilog: $(VERILOG_PREFIX).fs

build-spinal: $(SPINAL_PREFIX).fs

spinal-verilog: $(SPINAL_SRC)

$(BUILD)/.dir:
	mkdir -p $(BUILD)
	touch $@

$(SPINAL_SRC): src/main/scala/tangminer/TangMiner.scala build.sbt project/build.properties | $(BUILD)/.dir
	$(SBT) "runMain tangminer.GenerateVerilog"

$(VERILOG_PREFIX).json: $(SRC) | $(BUILD)/.dir
	$(YOSYS) -p "read_verilog $(SRC); synth_gowin -top $(TOP) -json $@"

$(VERILOG_PREFIX)_pnr.json: $(VERILOG_PREFIX).json $(CST)
	$(NEXTPNR) --json $< --write $@ --freq 27 --device $(DEVICE) -o family=$(FAMILY) -o cst=$(CST)

$(VERILOG_PREFIX).fs: $(VERILOG_PREFIX)_pnr.json
	$(GOWIN_PACK) -d $(FAMILY) -o $@ $<

$(SPINAL_PREFIX).json: $(SPINAL_SRC) | $(BUILD)/.dir
	$(YOSYS) -p "read_verilog $(SPINAL_SRC); synth_gowin -top $(TOP) -json $@"

$(SPINAL_PREFIX)_pnr.json: $(SPINAL_PREFIX).json $(CST)
	$(NEXTPNR) --json $< --write $@ --freq 27 --device $(DEVICE) -o family=$(FAMILY) -o cst=$(CST)

$(SPINAL_PREFIX).fs: $(SPINAL_PREFIX)_pnr.json
	$(GOWIN_PACK) -d $(FAMILY) -o $@ $<

load: load-spinal

load-verilog: $(VERILOG_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) $<

load-spinal: $(SPINAL_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) $<

flash: flash-spinal

flash-verilog: $(VERILOG_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) -f $<

flash-spinal: $(SPINAL_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) -f $<

sim: sim-sha sim-bitcoin

sim-sha: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_sha256_compress sim/tb_sha256_compress.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_sha256_compress

sim-bitcoin: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_bitcoin_hash_core sim/tb_bitcoin_hash_core.v src/bitcoin_hash_core.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_bitcoin_hash_core

clean:
	rm -rf $(BUILD)
