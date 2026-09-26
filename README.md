Secure RISC-V SoC Data Logger for Mission-Critical Telemetry (Kavach / TCAS)

1. Motivation
Modern safety-critical transportation systems — most notably India's Train Collision Avoidance System (TCAS/Kavach) — depend on continuous, real-time logging of operational telemetry: train speed, signal aspect, brake pipe pressure, braking commands, and driver inputs. This data is the backbone of incident forensics, regulatory compliance, and post-accident investigation.
Why this matters in real time:
Handling continuous high-rate sensor streams purely in software forces the CPU to repeatedly service interrupts and run memory-copy/crypto routines, causing pipeline stalls, jitter, and — in the worst case — dropped telemetry during exactly the burst of activity (e.g., a hard brake) that investigators need most.
Telemetry stored without hardware-level cryptographic protection is tamper-able, which undermines its value as forensic evidence.
A firmware hang or bus deadlock, if undetected, can silently stop logging altogether with no operator awareness.
How this project addresses it:
 This SoC offloads memory transfer, encryption, and health-monitoring to dedicated autonomous hardware blocks, so the control processor never becomes the bottleneck. The result is:
Zero telemetry loss under sustained sensor throughput (hardware handshaking, not CPU polling)
Constant-time, tamper-resistant cryptographic protection of every logged block (hardware AES, not a software library with cache-timing side channels)
Autonomous fault isolation — a watchdog that can force recovery even if the CPU or DMA has completely locked up, with zero software involvement
The direct benefit: a data logger that keeps recording accurately and securely exactly when the system is under the most stress — which is when the log matters most.

2. Block Diagram
Full architecture diagram: View on : https://app.diagrams.net/#G1E4_oNCy5_rBY-oTDDtPXRc-Tu5abfEbk#%7B%22pageId%22%3A%22CIzeiW2PUjdxlhk8X_p7%22%7D


4. System Architecture & IPs Used
Core processor: 
RISC-V Processor Core — VeeR EL2 (Western Digital / CHIPS Alliance): Open-source, dual-issue 32-bit core implementing RV32IMC, with 32 KB ICCM and 64 KB DCCM. It's the control-plane master — configuring peripheral registers, handling top-level interrupts/fault vectors — while the closely-coupled memories let it run control code at deterministic, single-cycle latency without contending for the shared AXI bus. This is what makes non-blocking CPU execution possible even while DMA is saturating the bus.
Bus fabric

Dual-Master AXI4-Lite Interconnect: Crossbar with round-robin arbitration between Master 1 (RISC-V core) and Master 2 (DMA). Chosen for low area overhead and standardized handshaking; the round-robin arbiter is what gives the zero-starvation guarantee — high-bandwidth DMA traffic can never lock the CPU out of its control registers.

The six integrated peripheral IPs
AES Encryption Engine (AXI4-Lite slave): Hardware-accelerated AES-128/256 (ECB/CBC) over staged sensor blocks. Removes the latency and cache-timing side-channel risk of software crypto, and its completion pulse doubles as the hardware "system alive" heartbeat for the watchdog.
Bus-Mastering DMA Controller (AXI4-Lite slave + master): Moves UART telemetry into staging SRAM autonomously once a FIFO threshold is crossed — no CPU polling loops, no programmatic I/O. Its completion pulse triggers the AES engine directly.

Watchdog Timer (WDT): Autonomous supervisor with an early-warning IRQ, an NMI line, and a hard reset line, all independent of software. Wired to auto-kick on every AES completion, so any hang anywhere in the pipeline (UART → DMA → AES) is detected and recovered from without firmware intervention — critical for a safety-rated system.

UART: The sensor ingest interface; asserts a hardware DMA request the moment its RX FIFO crosses a watermark, starting the autonomous pipeline with zero CPU involvement.

GPIO/Timer: Provides board-level I/O and timing references (baud generation, peripheral clocking) supporting the rest of the pipeline.
Programmable Interrupt Controller (PIC): Aggregates and priority-encodes interrupts from DMA, AES, UART, and WDT-warning into a single vectored line to the core — keeping the CPU's interrupt handling simple even though multiple autonomous blocks are running in parallel.
Supporting element: a 32 KB dual-port staging SRAM (Port A → AES, Port B → DMA/CPU) that decouples ingest from cryptographic processing, avoiding bus contention between the two.

Key architectural guarantees
Hardware-synchronized autonomous pipeline: UART → DMA → SRAM → AES → WDT kick, entirely in hardware, no software intervention.
Zero-starvation arbiter: transaction-boundary round-robin locking bounds CPU wait time regardless of DMA load.
Non-blocking CPU execution: the core only stalls if it explicitly issues an off-chip AXI transaction; otherwise it runs at full speed from ICCM/DCCM.
Privilege and bus protection: Master 2 (DMA) is hardware-blocked from writing to CPU-only registers (AES keys, WDT control); unaligned accesses return SLVERR.

6. References
RISC-V VeeR EL2 core (Western Digital / CHIPS Alliance), open-source RTL: https://github.com/chipsalliance/Cores-VeeR-EL2
RISC-V Instruction Set Manual, Volume I: Unprivileged ISA — RISC-V International: https://riscv.org/technical/specifications/
Arm AMBA AXI and ACE Protocol Specification (AXI4 / AXI4-Lite): https://developer.arm.com/documentation/ihi0022/latest/
FIPS 197, Advanced Encryption Standard (AES) — NIST: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
AMBA AXI4-Lite UART reference behavior (register map / TX-RX FIFO conventions used as the design baseline for axi_uart_top) — consistent with the LogiCORE AXI UART Lite v2.0 specification: https://docs.amd.com/v/u/en-US/pg142-axi-uartlite
Synopsys VCS / Verdi User Guides (simulation and waveform debug tooling used for verification)
(If any of the UART/AES/DMA/WDT RTL was sourced from a specific third-party repo rather than written from scratch, add that exact link here for proper attribution.)



7. Repository Structure
SOC_Datalogger_project/
├── Docs/                          # Spec doc, session log, error log
├── RTL_files/                     # Top-level integration RTL (bridge, wrapper, timescale stub)
├── TB_files/                      # SystemVerilog testbenches
├── Scripts/                       # Build/utility scripts
├── run/                           # Filelists and run scripts (VCS compile/sim)
├── axi-lite_uart-ipcore-develop/  # UART IP core source (RTL + docs)
└── README.md


8. Register Map
UART (base 0x4000_0000, 32 B aperture)
Offset
Register
Description
0x00
RBR / THR
RX buffer / TX holding
0x04
IER
Interrupt enable
0x08
BAUD
Baud divisor
0x0C
LCR
Line control (8N1 = 0x03)
0x14
LSR
Line status (TEMT=bit6, THRE=bit5, DATA_READY=bit0)

DMA Controller (base 0x4000_3000)
Offset
Register
Description
0x00
DMA_SRC_ADDR
Source address pointer
0x04
DMA_DST_ADDR
Destination address pointer (SRAM Port B)
0x08
DMA_XFER_LEN
Transaction length in bytes
0x0C
DMA_CTRL
START (bit0), IRQ_EN (bit1), MODE_SEL (bit2)
0x10
DMA_STATUS
BUSY (bit0), DONE (bit1), ERROR (bit2)

AES Engine (base 0x4000_2000)
Offset
Register
Description
0x00
AES_CTRL
START (bit0), MODE (bit1), DIR (bit2), SRAM_AUTO_FETCH (bit3)
0x04
AES_STATUS
IDLE / PROCESSING / COMPLETE
0x10–0x2C
AES_KEY_0..7
128/256-bit key words

Watchdog Timer (base 0x4000_4000)
Offset
Register
Description
0x00
WDT_MAX_LIMIT
Timeout threshold (cycles)
0x04
WDT_CTRL
Auto-kick enable, NMI mode, hard-reset config
0x08
WDT_PING_REG
Manual software ping (CPU ISR fallback)


7. How to Build & Run
cd run

# Compile (recommended, with log capture)
vcs -full64 -sverilog -l compile.log -f run_interconnect_uart.f -o simv_ic_uart

# Simulate
./simv_ic_uart

# With Verdi waveforms
vcs -full64 -sverilog -debug_access+all -kdb -f run_interconnect_uart.f -o simv_ic_uart
./simv_ic_uart -verdi



8. Verification Status
The AXI-interconnect ↔ UART integration is verified with a directed 7-step test sequence in tb_interconnect_uart.sv:
Reset — hold rst_n low for 20 clocks
LCR config — write 0x03 (8N1)
BAUD config — write SIM_BAUD_DIV = 10
THR write — write 0x55 to transmit register
LSR poll TEMT — wait for TX FIFO drain
RX injection — drive byte 0xA5 on uart_rx (NRZ, LSB-first)
RBR read — verify received byte equals 0xA5
All 7 tests currently pass. This verified interconnect–UART block has since been integrated into the RISC-V wrapper (VeeR EL2), and verification of that integrated block is currently in progress.
AES, DMA, WDT, and PIC integration into the full top-level SoC is planned next and not yet covered by any testbench — update this section as each stage's verification lands.


9. Challenges & Debugging

8 documented root-cause debugging entries during interconnect–UART bring-up — full detail in Docs/error_log.md. Summary:
**NTSFM (missing timescale, first attempt):** A shared timescale.v` stub listed first in the filelist looked correct but didn't propagate across file boundaries in VCS.
SVS (SystemVerilog-only syntax): rd = '0; rejected outside full SV mode; replaced with {DATA_W{1'b0}}.
NTSFM (real root cause): VCS resets timescale context at every file boundary — the directive must be embedded inside each of the 6 UART source files individually, not left in a shared stub.
TFIPC (too few port connections): Tie-off logic for unused master ports (m01–m05) wired only the input side; 32 output ports per master were missing. Fixed by tying outputs to () and driving inputs with literals in the instantiation.
SIOB + NMCM (OOB slice / negative replication): ID-width conversion assumed the interconnect ID width was ≥ the UART's fixed 12-bit ID; it was actually 8-bit, causing an illegal negative replication. Fixed by reversing the conversion direction (zero-pad 8→12 in, truncate 12→8 out).
UST (undefined system task): `ifdef VCS always selected the FSDB dump branch (VCS defines that macro by default), but the Verdi/Novas PLI library wasn't loaded. Replaced with unconditional $dumpfile/$dumpvars.
Runtime $finish (address width violation): The interconnect enforces a minimum 12-bit (4 KB) slave address aperture; UART's real footprint is 5 bits (32 B). Fixed by setting M00_ADDR_WIDTH = 12 regardless, with unused address space returning SLVERR.
Stale-binary false negative: The same runtime error persisted after the fix above because simv_ic_uart was a stale compiled binary. Solved with build_ic_uart.sh, which always clears prior build artifacts before recompiling.
Recurring lesson: several issues looked fixed after the first pass but weren't — the root cause in both the timescale bug and the stale-binary bug was tool behavior (per-file timescale reset, cached binaries), not the RTL itself.

11. Skills & Tools Demonstrated
RTL design in Verilog / SystemVerilog
AXI4 and AXI4-Lite protocol implementation (interconnect, bridge, peripheral slaves)
RISC-V SoC integration (VeeR EL2 core)
Testbench development and directed verification methodology
Synopsys VCS (compilation, simulation) and Verdi (FSDB waveform debug)
Systematic root-cause debugging across compile-time (NTSFM, SVS, TFIPC, SIOB, NMCM, UST) and runtime errors
Hardware security: AES-128/256 cryptographic acceleration
Fault-tolerant system design: autonomous watchdog-based recovery

12. Author
Nitish — Final-year B.E. Electronics and Communication Engineering, Vasavi College of Engineering (VCE), Hyderabad. Trained in Semiconductor device fabrication at CENSE IISc Banglore, Samsung SSIR Fellow · ISWDP certified (IISc, Synopsys, Samsung).
Email : nitishlingampalle@ieee.org
LinkedIn : https://www.linkedin.com/in/nitishlingampalle25/

