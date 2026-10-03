# Control Path
### Secure RISC-V SoC Data Logger — TCAS/Kavach Telemetry Subsystem
**Document type:** Hardware Control-Path Specification
**Companion documents:** `Datapath.md`, `SOC_Datalogger_Address_Map_FINAL.xlsx`

---

## 1. Scope

This document specifies the **control-plane architecture**: the bus fabric, address
decoding, arbitration, register-level configuration interfaces, interrupt routing,
and reset/fault-recovery control of the SoC. It does not describe the movement of
telemetry payload data itself — that is covered in `Datapath.md`.

---

## 2. Bus Fabric

### 2.1 Topology

```
                 ┌─────────────────────────────┐
  RISC-V (M1) ───▶                             │
                 │   axi_interconnect_wrap_2x6   │
  DMA (M2)   ───▶│   (AXI4 crossbar, 2M x 6S)    │
                 └──────┬──────┬──────┬──────┬──┘
                        m00    m01    m02    m03 ... m05
                        │      │      │      │
                     [bridge][bridge][bridge][bridge]  (AXI4 → AXI4-Lite,
                        │      │      │      │          per-slave, where needed)
                      UART  RV_TIMER  AES    DMA(CSR) ...
                            + GPIO
```

- **Masters:** Master 1 = RISC-V VeeR EL2 core; Master 2 = DMA Controller (acting as
  bus master for its autonomous data-mover role — distinct from its own CSR slave
  port, which Master 1 configures).
- **Slaves:** 6 master-side ports (`m00`–`m05`) on the interconnect, each decoded off
  `ADDR[31:12]`, each carrying a fixed 4 KB aperture.
- **Protocol:** the interconnect core is full AXI4 internally. Each peripheral slave
  that only implements AXI4-Lite (UART, AES, DMA-CSR, WDT) sits behind a per-port
  `axi4_to_axilite_bridge` instance that drops `awlen`/`wlast`/`arlen`/burst
  signaling and forces single-beat transactions. RV_TIMER additionally requires a
  **protocol** bridge (TileLink-UL → AXI4-Lite), not just a burst-width adapter — see
  §2.4.

### 2.2 Address Decoding

Per Spec_Doc.odt §4: the interconnect's central decoder evaluates `ADDR[31:12]` to
route a transaction to the correct slave port. Full port assignment is in
`SOC_Datalogger_Address_Map_FINAL.xlsx` (`IP Map` sheet); summary:

| Port | Base | Peripheral |
|---|---|---|
| m00 | `0x4000_0000` | UART |
| m01 | `0x4000_1000` | RV_TIMER (System Timer) + GPIO (sub-decoded) |
| m02 | `0x4000_2000` | AES Engine |
| m03 | `0x4000_3000` | DMA Controller (CSR) |
| m04 | `0x4000_4000` | Watchdog Timer |
| m05 | `0x4000_5000` | PIC |

### 2.3 Port-Count Constraint (open item)

The 2×6 interconnect has exactly 6 slave-facing ports. With UART, RV_TIMER, AES,
DMA, WDT, and PIC each requiring one, **GPIO has no dedicated port.** This document
assumes GPIO is sub-decoded inside RV_TIMER's 4 KB window using a secondary 3-bit
address comparator inside that port's local bridge logic (GPIO registers placed at
offset `0x800`+, clear of RV_TIMER's own register footprint which tops out at
`0x11C`). This is a design decision pending sign-off — see
`Notes_Open_Items` in the address-map workbook.

### 2.4 RV_TIMER Bus Protocol Bridge

RV_TIMER (sourced from OpenTitan) is a **Comportable TileLink-Uncached-Lite (TL-UL)**
peripheral (`interfaces.md`: *Bus Device Interfaces (TL-UL): `tl`*), not AXI4-Lite.
Unlike the other peripherals, plugging it into `m01` requires a **protocol bridge**
(TL-UL ↔ AXI4-Lite transaction/handshake translation), not merely a burst-width
adapter. This is new RTL work, not yet written, and is the single largest piece of
integration effort among the currently-selected IPs.

---

## 3. Arbitration (AXI4-Lite Dual-Master Round-Robin)

Per Spec_Doc.odt §4, verbatim architecture carried into this document:

### 3.1 Fair-Share Priority Pointer
- A 1-bit internal state register, `last_granted_master`, tracks which master was
  last serviced.
- If Master 1 (CPU) was granted on the previous cycle, Master 2 (DMA) moves to top
  priority for the next pending request, and vice versa.
- If only one master is requesting, it is granted immediately regardless of pointer
  state — no idle latency cycles are introduced by the arbitration scheme itself.

### 3.2 Non-Preemptive Transaction Locks
- Arbitration occurs strictly at **transaction boundaries**. Once a master asserts
  `AWVALID` or `ARVALID` and is granted, it retains the bus until the full AXI
  handshake resolves (`BVALID`/`BREADY` for writes, `RVALID`/`RREADY` for reads).
- The arbiter **cannot** preempt or split an active transfer mid-cycle.

### 3.3 Independent Channel Handshaking
- **AW + W channels** are multiplexed together per write request; the arbiter
  routes `AWADDR`, `WDATA`, `WSTRB` to the target slave and returns `AWREADY`/
  `WREADY` to the granted master.
- **AR + R channels** are multiplexed independently of writes, allowing concurrent
  bidirectional bus activity where the target slave supports split read/write
  channels.

### 3.4 Zero-Starvation Guarantee
Under sustained sensor throughput, the DMA Controller issues continuous writes into
the 32 KB Staging SRAM. Round-robin enforcement prevents these high-bandwidth DMA
writes from locking out the CPU — the CPU can interleave register configuration or
health checks on alternating grants even under heavy DMA load.

### 3.5 CPU Stall Behavior
When Master 2 (DMA) holds the bus, the RISC-V core **only stalls if it explicitly
issues an off-chip AXI transaction.** As long as the core executes from its internal
32 KB ICCM and accesses its 64 KB DCCM, it runs at full speed independent of the
active AXI grant state — this is the architectural basis for the "non-blocking CPU
execution" claim in the project README.

---

## 4. Access Control & Protection

### 4.1 Privilege Guards
Per Spec_Doc.odt §4: register-protection flags prevent Master 2 (DMA) from writing
into control registers reserved exclusively for Master 1 (CPU). Concretely, in the
current register map:

| Protected Register Block | Enforcement |
|---|---|
| `AES_KEY_0..3` (`0x4000_2010`–`0x4000_201C`) | CPU-only write; DMA write attempts return `SLVERR` |
| `WDT_CTRL`, `WDT_IM`, `WDT_IC` (`0x4000_4008`, `0x4000_4010`, `0x4000_401C`) | CPU-only write |

### 4.2 Alignment Guards
Unaligned address transfers (e.g., a 32-bit word access on a non-4-byte boundary)
trigger an `SLVERR` response, per the existing interconnect behavior already
verified for the UART integration (see `error_log.md`, entries unrelated to this
but establishing the SLVERR convention is already exercised in simulation).

### 4.3 RV_TIMER-Specific Protection
RV_TIMER additionally implements its own **end-to-end TileLink bus-integrity
countermeasure** (`RV_TIMER.BUS.INTEGRITY`, per `interfaces.md`), raising a
`fatal_fault` alert (`ALERT_TEST` / `fatal_fault` bit) on a detected TL-UL integrity
violation. This is a security feature internal to the sourced IP and is additive to
— not a replacement for — the SoC-level `SLVERR`/`DECERR` conventions used
elsewhere.

---

## 5. Per-Peripheral Control (Register-Level Summary)

Full bit-field detail lives in the address-map workbook (`Register Map` sheet).
Control-path role of each block:

### 5.1 UART — `AXI4-Lite Slave`
`LCR` configures frame format; `BAUD` sets the divisor; `IER`/`LSR` gate and report
RX/TX status. No autonomous bus-mastering — purely CPU/DMA-addressed.

### 5.2 RV_TIMER — `TL-UL Slave` (bridged)
Implements the RISC-V-privileged-spec machine timer model directly in hardware:
- `TIMER_V_LOWER0`/`TIMER_V_UPPER0` form the 64-bit `mtime` register, incremented by
  an internal tick generator whose period is set via `CFG0.prescale`/`CFG0.step`
  (`theory_of_operation.md`).
- `COMPARE_LOWER0_0`/`COMPARE_UPPER0_0` form `mtimecmp`. A timer interrupt is
  asserted in hardware whenever `mtime ≥ mtimecmp` (`programmers_guide.md`).
- `CTRL.active_0` gates whether the counter runs at all.
- `INTR_ENABLE0`/`INTR_STATE0`/`INTR_TEST0` follow OpenTitan's standard
  enable/raw-status/software-test interrupt convention; `INTR_STATE0` is
  **write-1-to-clear**.
- **Firmware note** (from `programmers_guide.md`, carried forward because it is a
  real correctness hazard): the 64-bit `mtime`/`mtimecmp` values are accessed as two
  32-bit register halves. A torn (non-atomic) read across the 32-bit boundary is
  possible; firmware must use the three-read `rdcycleh`/`rdcycle`/`rdcycleh`
  comparison pattern from the RISC-V unprivileged spec to detect and retry. The
  `mtimecmp` update sequence must similarly write `0xFFFF_FFFF` to the lower half
  first to avoid a spurious interrupt mid-update.
- The hardware `timer_expired_hart0_timer0` interrupt line feeds the PIC and, in
  parallel, is intended to drive VeeR EL2's external `timer_int`/`mtip` input,
  matching the standard SweRV/VeeR CLINT-equivalent integration pattern.

### 5.3 AES Engine — `AXI4-Lite Slave` (wraps a raw cipher core)
Unlike a conventional MMR-driven crypto accelerator, the underlying ASICS.ws
Rijndael core has **no native register interface at all** — it is a bare datapath
(`clk`, `rst`, `ld`, `done`, `key[128]`, `text_in[128]`, `text_out[128]` for
encrypt; additionally `kld`/`kdone` for decrypt). The project's `AES_CTRL`/
`AES_STATUS` registers are therefore a **from-scratch control wrapper**, not a
pass-through of existing CSRs:
- `AES_CTRL.START` pulses the core's `ld` input.
- `AES_CTRL.DIR_SEL` selects which of the two sub-cores (`aes_cipher_top` /
  `aes_inv_cipher_top`) receives the pulse.
- `AES_CTRL.KEY_LOAD` pulses `kld` on the inverse-cipher core only — **required
  before every decrypt session**, since the inverse cipher consumes its expanded
  key schedule in reverse order and cannot begin decryption until `kdone` asserts.
  This is a hard sequencing dependency with no equivalent on the encrypt path.
- `AES_STATUS.DONE`/`AES_STATUS.KDONE` mirror the core's `done`/`kdone` outputs.
- The core completes a full 128-bit block in a fixed **12 clock cycles** (10 rounds
  + 1 key-expansion cycle + 1 output-stage cycle) — a deterministic, documented
  latency useful for timing budget calculations elsewhere in the project.
- **No AES-256 support** and **no direct SRAM read/write port** exist in the
  sourced core — see `Notes_Open_Items` #3 in the address-map workbook.

### 5.4 DMA Controller — `AXI4-Lite Slave (CSR) + AXI4-Lite Master (data)`
`DMA_CTRL.START` begins a transfer using the programmed `DMA_SRC_ADDR`/
`DMA_DST_ADDR`/`DMA_XFER_LEN`. `DMA_CTRL.MODE_SEL` chooses single-shot vs.
auto-burst-reload. `DMA_STATUS` is polled (or interrupt-driven via `IRQ_EN`) by the
CPU, but the actual data motion is autonomous — see `Datapath.md` §2.

### 5.5 Watchdog Timer — `AXI4-Lite Slave` (wraps EF_WDT32)
`WDT_CTRL` bit 0 maps to the native EF_WDT32 `control` register (enable/disable);
bits 1–3 are **project-level extensions**, not present in the native core, that
this wrapper must implement in new logic: `AUTO_KICK_EN` (routes `AES_DONE_PULSE`
into `WDTLOAD`-reload logic), `NMI_MODE_EN`, and `HARD_RESET_EN` (both gate how the
wrapper escalates `WDTTO` into `CPU_NMI` / `CPU_RESET`, since the native core only
exposes a single raw timeout flag with no built-in escalation tiers — see
`Datapath.md` §5 for the full fault-escalation sequence). `WDT_IM`/`WDT_RIS`/
`WDT_MIS`/`WDT_IC` are the native core's interrupt mask/raw-status/masked-status/
clear registers, remapped to compact offsets per `Notes_Open_Items` #4.

### 5.6 PIC — `AXI4-Lite Slave`
Aggregates `IRQ_DMA_DONE`, `IRQ_AES_DONE`, `IRQ_UART_THOLD`, `IRQ_WDT_WARN`, and
(pending RTL) `timer_expired_hart0_timer0` into the single vectored `PIC_CPU_INT`
line. Register set in the address map is a placeholder — not yet implemented (see
`Notes_Open_Items` #6).

---

## 6. Interrupt & Reset Control Summary

| Signal | Source | Destination | Path |
|---|---|---|---|
| `IRQ_DMA_DONE` | DMA Controller | PIC → core | Software-serviced |
| `IRQ_AES_DONE` | AES Engine | PIC → core | Software-serviced |
| `IRQ_UART_THOLD` | UART | PIC → core | Software-serviced |
| `timer_expired_hart0_timer0` | RV_TIMER | PIC → core (and/or direct `mtip`) | Software-serviced / core-native |
| `IRQ_WDT_WARN` | WDT (`WDT_WARN_OUT`) | PIC → core | Software early-warning |
| `CPU_NMI` | WDT (`WDT_NMI_OUT`) | Core (direct) | Hardware, bypasses PIC |
| `CPU_RESET` | WDT (`WDT_RESET_OUT`) | Core + system reset tree (direct) | Hardware, bypasses PIC and software entirely |

The NMI and hard-reset paths are deliberately **not** routed through the PIC —
this is the architectural basis for the project's "autonomous fault isolation
independent of software execution state" claim, and must be preserved exactly as
direct point-to-point hardware connections in RTL.

---

## 7. Status

| Section | Status |
|---|---|
| Round-robin arbiter | Specified (Spec_Doc.odt); verified only for UART path to date |
| UART control registers | Verified (directed testbench, 7/7 passing) |
| AES control wrapper | Redesigned this revision to match sourced core; RTL not yet written |
| DMA control registers | Specified; RTL integration in progress |
| WDT control wrapper | Specified; RTL not yet written |
| RV_TIMER control interface | Specified; TL-UL↔AXI4-Lite bridge not yet written |
| PIC | Placeholder only; RTL not yet written |
