# Data Path
### Secure RISC-V SoC Data Logger — TCAS/Kavach Telemetry Subsystem
**Document type:** Hardware Data-Path Specification
**Companion documents:** `Control_Path.md`, `SOC_Datalogger_Address_Map_FINAL.xlsx`

---

## 1. Scope & Design Intent

The data path is designed for **zero-CPU-intervention** during continuous,
high-throughput TCAS telemetry logging. Data moves autonomously from sensor input
to encrypted storage using dual-port SRAM staging and hardware handshaking —
no software polling loop or ISR sits on the critical path from sensor byte to
encrypted-block-at-rest. This document traces that path step by step, signal by
signal.

---

## 2. End-to-End Pipeline Overview

```
TCAS Sensors ──▶ UART RX FIFO ──▶ [UART_DMA_REQ] ──▶ DMA Controller (Master 2)
                                                            │
                                                  AXI write, Port B
                                                            ▼
                                         32 KB Dual-Port Staging SRAM
                                         (Buffer 0 / Buffer 1 ping-pong)
                                                            │
                                                [DMA_XFER_COMPLETE]
                                                            ▼
                                              AES Engine (Port A read)
                                        ld → 12-cycle cipher round → done
                                                            │
                                          encrypted block written back, Port A
                                                            │
                                                [AES_DONE_PULSE]
                                                            ▼
                                     Watchdog Timer hardware kick (WDT_KICK_HW)
                                        (counter reset to zero — no CPU cycle spent)
```

---

## 3. Step 1 — Ingestion & Buffer Threshold Signaling

- **Data arrival:** serial telemetry bytes (speed, braking state, signal aspect,
  driver input) from TCAS sensors stream into the UART's RX FIFO.
- **Hardware trigger:** when FIFO fill level crosses a configured watermark, UART
  asserts `UART_DMA_REQ` **directly to the DMA Controller — no CPU interrupt is
  involved in starting the transfer.**
- **Bus request:** on receiving `UART_DMA_REQ`, the DMA Controller prepares an AXI
  transaction as Master 2 and asserts `DMA_BUSREQ` to the round-robin arbiter.

| Signal | Direction | Description |
|---|---|---|
| `UART_DMA_REQ` | UART → DMA | FIFO watermark crossed |
| `UART_DMA_ACK` | DMA → UART | DMA confirms receipt of the request |
| `DMA_BUSREQ` / `DMA_BUSGNT` | DMA ↔ Arbiter | Master 2 bus grant handshake |

---

## 4. Step 2 — Zero-Copy Staging Transfer (DMA as AXI Master)

- **Bus arbitration:** DMA requests control via the round-robin arbiter (see
  `Control_Path.md` §3). On grant, it executes read cycles against the UART data
  register.
- **Direct memory transport:** as Master 2, the DMA writes the fetched stream
  directly into **Port B** of the 32 KB Dual-Port Staging SRAM, base
  `0x5000_0000`.
- **Non-blocking CPU execution:** the CPU continues executing from its local
  ICCM/DCCM uninterrupted throughout this transfer (see `Control_Path.md` §3.5).
- **Transfer completion:** when the running byte count reaches `DMA_XFER_LEN`, the
  DMA deasserts `UART_DMA_REQ` and drives `DMA_XFER_COMPLETE` — a single hardware
  pulse, no CPU involvement.

| Signal | Width | Description |
|---|---|---|
| `DMA_SRC_PTR` | `[31:0]` | Active source read address (UART data register) |
| `DMA_DST_PTR` | `[31:0]` | Active destination write address (SRAM Port B) |
| `DMA_BYTE_COUNT` | `[15:0]` | Down-counter tracking remaining bytes in the burst |
| `DMA_ACTIVE` | 1 | Asserted while the DMA FSM is mid-transfer |
| `DMA_ERR_RESP` | 1 | Set if the DMA receives `SLVERR`/`DECERR` during the transfer |
| `DMA_XFER_COMPLETE` | 1 | Pulse — hardware sync signal that starts Step 4 |

---

## 5. Step 3 — Dual-Port SRAM Memory Isolation

- **Concurrent access:** the dual-port topology lets DMA write incoming telemetry
  over **Port B** while AES independently reads/processes a previous block over
  **Port A** — no bus contention between ingest and cryptographic processing.
- **Ping-pong partitioning:**

| Buffer | Address Range | Role |
|---|---|---|
| Buffer 0 | `0x5000_0000`–`0x5000_3FFF` (16 KB) | While Port B fills Buffer 1, Port A drains/transmutes Buffer 0 |
| Buffer 1 | `0x5000_4000`–`0x5000_7FFF` (16 KB) | Roles swap each cycle |

| Signal | Port | Description |
|---|---|---|
| `SRAM_PORTA_ADDR[14:0]` | A (AES) | Address bus for reading raw blocks / writing ciphertext |
| `SRAM_PORTA_WDATA[32:0]` | A (AES) | Encrypted ciphertext write data |
| `SRAM_PORTA_RDATA[32:0]` | A (AES) | Raw cleartext read data |
| `SRAM_PORTA_WE` | A (AES) | Write-enable, commits transmutation output |
| `SRAM_PORTB_ADDR[14:0]` | B (DMA/CPU) | Address bus for DMA staging writes / CPU debug reads |
| `SRAM_PORTB_WDATA[32:0]` | B (DMA) | Incoming UART telemetry write data |
| `SRAM_PORTB_RDATA[32:0]` | B (DMA/CPU) | Staged memory read-back |
| `SRAM_PORTB_WE` | B (DMA) | Write-enable during active DMA write transfers |

---

## 6. Step 4 — AES Transmutation (Revised for the Sourced Core)

**This step differs materially from the original architectural assumption and is
the most important update in this revision.**

The originally specified AES block assumed a `SRAM_AUTO_FETCH` capability — the
AES engine autonomously pulling blocks from SRAM Port A with no register-mediated
staging. The actual sourced core (ASICS.ws Rijndael IP, `aes_cipher_top.v` /
`aes_inv_cipher_top.v`) **has no SRAM or memory interface of any kind.** It is a
pure combinational/sequential datapath with only these ports:

| Port | Width | Direction | Role |
|---|---|---|---|
| `clk` | 1 | in | Core clock |
| `rst` | 1 | in | Active-low **synchronous** reset |
| `ld` | 1 | in | Pulse to begin an encrypt (or decrypt) sequence |
| `done` | 1 | out | Pulses 1 cycle on sequence completion |
| `key` | 128 | in | Encryption/decryption key (128-bit only) |
| `text_in` | 128 | in | Input block (plaintext for encrypt, ciphertext for decrypt) |
| `text_out` | 128 | out | Output block |
| `kld` *(decrypt only)* | 1 | in | Pulse to begin key-schedule expansion |
| `kdone` *(decrypt only)* | 1 | out | Pulses when key expansion for decrypt is ready |

**Revised data-path sequence:**
1. `DMA_XFER_COMPLETE` triggers the project's AES control wrapper (see
   `Control_Path.md` §5.3), **not** the raw core directly.
2. The wrapper reads a 128-bit block from SRAM Port A into the `AES_TEXT_IN_0..3`
   staging registers (4 × 32-bit reads — the wrapper performs this SRAM-to-register
   move in logic; the core itself never touches SRAM).
3. For **decrypt** only: the wrapper must first pulse `kld` and wait for `kdone`
   before any block can be processed — this is a hard sequencing dependency not
   present on the encrypt path, and not present at all in the originally assumed
   single-core design.
4. The wrapper pulses `ld`. The core completes the block in a fixed **12 clock
   cycles** (10 rounds + 1 key-expansion cycle + 1 output-stage cycle for encrypt;
   similarly fixed for decrypt once `kdone` has asserted).
5. On `done`, the wrapper latches `text_out` into `AES_TEXT_OUT_0..3` and writes it
   back into SRAM Port A at the same block location (ciphertext replaces
   cleartext in place).
6. The wrapper asserts `AES_DONE_PULSE` — functionally equivalent to the original
   spec's hardware pulse, but now sourced from wrapper logic rather than the core's
   native `done` output directly, since the full cycle includes the SRAM
   read-back/write-back the wrapper performs around the core.

**Design implications to carry forward:**
- **AES-256 is not available** from this core (192/256-bit variants are a
  commercially licensed ASICS.ws product, not included in this sourced IP).
- **Zero-CPU-latency is preserved** — all of the above (SRAM access, key loading,
  the 12-cycle cipher round) runs in wrapper hardware with no software cycles,
  matching the original non-functional requirement even though the control
  sequence is more involved than first assumed.
- Decrypt-session key-schedule setup (`kld`→`kdone`) adds latency on the decrypt
  path that does not exist on encrypt — relevant if decrypt is ever needed
  in-line on the logging path (e.g., for integrity verification) rather than only
  off-line during forensic review.

---

## 7. Step 5 — Autonomous Hardware Handshaking & Fault Supervision

### 7.1 Normal Servicing
- On completing a block, the AES wrapper asserts a 1-cycle `AES_DONE_PULSE`.
- This pulse routes **directly into the Watchdog Timer's hardware kick input**
  (`WDT_KICK_HW`), resetting its down-counter to zero.
- Result: the logging sequence maintains integrity autonomously — the CPU never
  spends execution cycles running a software kick-timer ISR.

### 7.2 Fault Condition
- **Trigger:** if a sensor interface hangs, an AXI transfer stalls, or the AES
  pipeline halts, `AES_DONE_PULSE` is suppressed.
- **Threshold crossing:** the WDT's internal counter increments until it exceeds
  `WDT_MAX_LIMIT` (mapped to the EF_WDT32 core's native `load` register via the
  project's control wrapper — see `Control_Path.md` §5.5).
- **Emergency assertion:** the WDT asserts `CPU_NMI` and/or `CPU_RESET` directly to
  the RISC-V core, forcing hardware-level recovery regardless of software state —
  entirely independent of the PIC and any interrupt service routine.

### 7.3 Signal Summary

| Signal | Source | Destination | Role |
|---|---|---|---|
| `AES_DONE_PULSE` | AES wrapper | WDT (`WDT_KICK_HW`) + PIC (`IRQ_AES_DONE`) | Normal-path kick + software notification |
| `WDT_WARN_OUT` | WDT | PIC (`IRQ_WDT_WARN`) | Early warning, soft recovery path |
| `WDT_NMI_OUT` | WDT | Core (`CPU_NMI`, direct) | Emergency, hardware-only |
| `WDT_RESET_OUT` | WDT | Core + system reset (`CPU_RESET`, direct) | Last-resort recovery, hardware-only |

---

## 8. Data-Path Timing Budget (reference figures)

| Stage | Latency | Source |
|---|---|---|
| AES block cipher round (encrypt) | 12 clock cycles | ASICS.ws core datasheet |
| AES block cipher round (decrypt, after `kdone`) | 12 clock cycles | ASICS.ws core datasheet |
| AES decrypt key-schedule setup (`kld`→`kdone`) | Not specified in sourced doc — **measure in simulation before relying on this for timing closure** | — |
| DMA transfer | Variable, proportional to `DMA_XFER_LEN` | Project-specified |
| WDT timeout window | Configurable via `WDT_MAX_LIMIT` | Project-specified — must exceed worst-case DMA + AES latency with margin |

---

## 9. Status

| Stage | Status |
|---|---|
| UART ingest → interconnect | Verified (directed testbench) |
| DMA zero-copy staging write | Specified; RTL integration in progress |
| Dual-port SRAM ping-pong | Specified; not yet instantiated |
| AES wrapper (revised for sourced core) | Redesigned this revision; RTL not yet written |
| WDT hardware auto-kick | Specified; RTL not yet written |
| End-to-end pipeline (UART→SRAM→AES→WDT) | Not yet verified together |
