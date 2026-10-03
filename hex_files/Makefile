# =============================================================================
# Makefile  –  Build uart_rw_test.c → ELF → HEX for VeeR EL2 simulation
# Run from: /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/
# =============================================================================

PROJ_ROOT := /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project
SNAPSHOT  := $(PROJ_ROOT)/RTL_files/Cores-VeeR-EL2/snapshots/default

CROSS     := riscv64-unknown-elf
CC        := $(CROSS)-gcc
OBJCOPY   := $(CROSS)-objcopy
OBJDUMP   := $(CROSS)-objdump
SIZE      := $(CROSS)-size

# RV32IMC – matches VeeR EL2 default config (no F/D extensions)
ARCH      := rv32imc_zicsr
ABI       := ilp32

CFLAGS    := -march=$(ARCH) -mabi=$(ABI) \
             -O1 -g \
             -static -nostdlib -nostartfiles \
             -Wall -Wextra \
             -ffreestanding \
             -fno-common \
             -fomit-frame-pointer

LDFLAGS   := -T $(SNAPSHOT)/link.ld \
             -Wl,--print-map

TARGET    := uart_rw_test
SRCS      := crt0.S uart_rw_test.c

# ---------------------------------------------------------------------------
all: $(TARGET).hex $(TARGET).dis
	@echo ""
	@echo "========================================================"
	@echo "  Build complete:"
	@echo "    ELF : $(TARGET).elf"
	@echo "    HEX : $(TARGET).hex  (use this in simulation)"
	@echo "    DIS : $(TARGET).dis  (disassembly for inspection)"
	@echo "========================================================"
	@$(SIZE) $(TARGET).elf

# Link
$(TARGET).elf: $(SRCS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ > $(TARGET).map 2>&1 || \
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

# Intel HEX (used by most RISC-V simulation hex loaders)
$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

# Verilog $readmemh compatible hex (binary sections only, no addresses)
$(TARGET).vmem: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

# Disassembly – very useful to check the generated instructions
$(TARGET).dis: $(TARGET).elf
	$(OBJDUMP) -d -S -M no-aliases $< > $@

# Show section addresses and sizes
info: $(TARGET).elf
	@echo ""
	@echo "=== Section layout ==="
	@$(OBJDUMP) -h $<
	@echo ""
	@echo "=== Symbol table (key symbols) ==="
	@$(CROSS)-nm -n $< | grep -E "_start|main|BSS|STACK|tohost"

clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).vmem \
	       $(TARGET).dis $(TARGET).map

.PHONY: all clean info
