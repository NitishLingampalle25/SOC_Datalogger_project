# TCAS SOC Project – Session Log
## Project: TCAS_SOC_project (Nitish_161 | Sem 7)
---

## Session 1 — 2026-09-19

### Task
Integrate the AXI Interconnect (`axi_interconnect_wrap_2x6`) with the AXI4-Lite
UART IP core (`axi_uart_top`), where the **UART acts as a slave** and the
**AXI Interconnect acts as the master** (routing transactions from upstream
masters to the UART peripheral).

### Files Created / Modified

| File | Action | Purpose |
|------|--------|---------|
| `RTL_files/axi4_to_axilite_bridge.v` | Created | Protocol adapter: converts AXI4 burst signals from the interconnect's master port down to AXI4-Lite (single-beat) for the UART |
| `RTL_files/axi_interconnect_uart_top.v` | Created | Top-level integration wrapper instantiating interconnect + bridge + UART |
| `RTL_files/timescale.v` | Created | Shared timescale stub (`1ns/1ps`) listed first in filelists to fix NTSFM errors |
| `TB_files/tb_interconnect_uart.sv` | Created | Testbench driving the AXI4 s00 slave port of the interconnect; runs 7 functional tests |
| `run/run_interconnect_uart.f` | Created | VCS filelist for the integration build |
| `Docs/session_log.md` | Created | This file |
| `Docs/error_log.md` | Created | Error log tracking all compile errors and fixes |

### Architecture Summary

```
Testbench (AXI4 master)
       |
       | s00 / s01 (AXI4 slave ports of interconnect)
       v
 axi_interconnect_wrap_2x6   <-- AXI4 crossbar (2 masters x 6 slaves)
       |
       | m00 (AXI4 master port → UART address range 0x4000_0000 + 5-bit aperture)
       v
 axi4_to_axilite_bridge       <-- drops awlen/wlast/arlen; truncates addr to 5 bits; rlast=1
       |
       v
 axi_uart_top                 <-- AXI4-Lite UART slave (TX/RX, 115200 baud configurable)
       |
       +---> uart_tx_o  (serial TX)
       +---> uart_read_irq_o (RX data-ready interrupt)
       <---  uart_rx_i  (serial RX)
```

### Address Map

| Peripheral | Base Address | Aperture |
|-----------|-------------|---------|
| UART      | `0x4000_0000` | 32 B (5-bit) |
| m01–m05   | `0x4000_1000`–`0x4000_5000` | Tied off (DECERR) |

### UART Register Map (offsets from base)

| Offset | Register | Description |
|--------|----------|-------------|
| `0x00` | RBR / THR | RX buffer / TX holding |
| `0x04` | IER | Interrupt enable |
| `0x08` | BAUD | Baud divisor |
| `0x0C` | LCR | Line control (8N1 = `0x03`) |
| `0x14` | LSR | Line status (TEMT=bit6, THRE=bit5, DATA_READY=bit0) |

### Testbench Test Sequence

1. **Reset** — hold `rst_n` low for 20 clocks
2. **LCR config** — write `0x03` (8 data bits, no parity, 1 stop bit)
3. **BAUD config** — write `SIM_BAUD_DIV = 10` for fast simulation
4. **THR write** — write `0x55` to transmit register
5. **LSR poll TEMT** — wait until TX FIFO drains
6. **RX injection** — drive byte `0xA5` on `uart_rx` pin (NRZ, LSB first)
7. **LSR poll DATA_READY** — wait until byte is in RX FIFO
8. **RBR read** — read received byte and verify `== 0xA5`

### How to Run

```bash
cd /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/run

# Compile
vcs -full64 -sverilog -f run_interconnect_uart.f -o simv_ic_uart

# Simulate
./simv_ic_uart

# With Verdi waveforms
vcs -full64 -sverilog -debug_access+all -kdb -f run_interconnect_uart.f -o simv_ic_uart
./simv_ic_uart -verdi
```

---
*Log maintained by Kiro AI assistant.*

---

## Session 1 — Error Fix Round 2 (2026-09-19)

### Errors Fixed

| ID | Error Code | File | Fix |
|----|-----------|------|-----|
| E004 | TFIPC – Too few port connections | `axi_interconnect_uart_top.v` | Added all 32 missing output ports per m01–m05 master (→ `()`), removed separate tieoff wire/assign block |
| E005 | SIOB + NMCM – OOB select + negative concat | `axi4_to_axilite_bridge.v` | Reversed ID width conversion: zero-pad IC ID (8-bit) up to 12-bit for UART; truncate 12-bit UART response ID back to IC ID width |
| E006 | UST – Undefined `$fsdbDumpfile`/`$fsdbDumpvars` | `tb_interconnect_uart.sv` | Removed `ifdef VCS` fsdb block; replaced with unconditional `$dumpfile`/`$dumpvars` |

### Modified Files (this round)
- `RTL_files/axi4_to_axilite_bridge.v`
- `RTL_files/axi_interconnect_uart_top.v`
- `TB_files/tb_interconnect_uart.sv`
- `Docs/error_log.md`
