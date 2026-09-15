# CNN Accelerator — FPGA-Based Edge-AI Vision Accelerator

A fully pipelined, parameterized **N×N CNN convolution accelerator** written in Verilog, designed for the **IEEE SSCS Egypt Chapter 2026 Student Design Competition**.

The design streams one grayscale pixel per clock cycle and produces one output feature-map pixel per clock cycle, using **zero BRAMs** and a DSP-based MAC array, to maximize the competition Figure of Merit.

---

## Table of Contents

- [Design Goals](#design-goals)
- [Specification Compliance](#specification-compliance)
- [Architecture](#architecture)
- [Module Reference](#module-reference)
- [Pipeline Timing](#pipeline-timing)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Verification](#verification)
- [Golden Reference Model](#golden-reference-model)
- [Implementation Results](#implementation-results)
- [Design Decisions and Trade-offs](#design-decisions-and-trade-offs)
- [Bonus Features](#bonus-features)
- [Assumptions](#assumptions)

---

## Design Goals

The competition ranks designs by the Figure of Merit:

```
                    Throughput (output pixels / cycle)
FOM = ───────────────────────────────────────────────────────────
        Power × (LUTs + 50 × DSPs + 100 × BRAMs)
```

Every architectural decision in this repository follows directly from that formula:

| Objective | How it is achieved |
|---|---|
| Maximize throughput | Fully pipelined streaming datapath, **1 output pixel/cycle**, no stalls after fill |
| Eliminate the 100× BRAM penalty | **Zero BRAMs** — line buffers map to SRLs, weight storage to distributed logic |
| Minimize the 50× DSP penalty | Exactly N×N multipliers, one per kernel tap, no redundant arithmetic |
| Minimize LUTs | Sequential kernel loader replaces a wide bank multiplexer; sign-extension-based saturation replaces two 20-bit comparators; grouped adder reduction |
| Minimize power | Global `shift_en` gating stops the entire datapath when no data is in flight; SAIF-driven power estimation from real switching activity |
| Exploit "free" resources | Flip-flops carry **no penalty** in the FOM, so pipeline depth is used aggressively to raise F<sub>max</sub> at zero FOM cost |

---

## Specification Compliance

| # | Requirement | Implementation |
|---|---|---|
| 1 | Input image ≥ 32×32 | `IMAGE_WIDTH` / `IMAGE_HEIGHT` parameters, verified at 32×32 and larger |
| 2 | Unsigned fixed-point input | 8-bit unsigned pixels (`pixel_in[7:0]`), full 0–255 grayscale range |
| 3 | Programmable N×N kernel | `KERNEL_DIM` parameter; weights written at runtime through the config port |
| 4 | 8-bit signed kernel coefficients | `weight_data_in` is `signed [7:0]`, range −128 to +127 |
| 5 | Stride = 1 | Sliding window advances one pixel per cycle |
| 6 | ≥ 16-bit signed output | 20-bit internal accumulator saturated to 16-bit signed output |
| 7 | ReLU (bonus) | Runtime-selectable via `relu_en` |
| 8 | Golden-model verification | MATLAB golden model + exported test vectors, bit-exact match |
| 9 | FPGA results | Utilization / timing / power reported below |
| 10 | Figure of Merit | Reported below |

---

## Architecture

![Architecture Block Diagram](Architecture%20Block%20Diagram/Architecture%20Block%20Diagram.png)

The datapath is a straight-line stream: pixels enter, a sliding window is formed, the window is multiplied against the active kernel, the products are reduced, and the result is saturated and optionally passed through ReLU.

```
                    ┌──────────────────────┐
  cfg_wr_en   ─────▶│                      │
  cfg_kernel_idx ──▶│  kernel_config_regs  │── active_weights_flat ──┐
  cfg_weight_addr ─▶│  (N banks + loader)  │── kernel_ready          │
  cfg_weight_data ─▶│                      │                         │
  active_kernel_sel▶└──────────────────────┘                         │
                                                                     ▼
  pixel_in ───▶┌───────────────────┐   window_flat   ┌─────────────────────┐
               │ window_generator  │────────────────▶│      pe_array       │
               │  (SRL line bufs)  │                 │ N² MACs + grouped   │
               └───────────────────┘                 │   adder reduction   │
                         ▲                           └──────────┬──────────┘
                         │ shift_en                             │ raw_sum [19:0]
                         │                                      ▼
  valid_in ───▶┌───────────────────┐              ┌─────────────────────────┐
               │   control_fsm     │──shift_en───▶│    post_processing      │
               │ row/col counters  │              │ saturation + ReLU       │
               │ valid alignment   │              └───────────┬─────────────┘
               └─────────┬─────────┘                          │
                         │                                    ▼
                         └──────── valid_out ────────▶  pixel_out [15:0]
```

### Top-Level Interface

```verilog
module top_cnn_accelerator #(
    parameter IMAGE_WIDTH  = 32,     // Input frame width
    parameter IMAGE_HEIGHT = 32,     // Input frame height
    parameter KERNEL_DIM   = 3,      // N for an N×N kernel
    parameter NUM_KERNELS  = 4,      // Number of stored kernel banks
    parameter USE_DSP      = "YES",  // "YES" = DSP multipliers, "NO" = LUT fabric
    parameter GROUP_SIZE   = 3       // MACs per combinational adder group
)(
    input  wire        clk,
    input  wire        rst_n,             // Asynchronous active-low reset

    // Kernel configuration port
    input  wire        cfg_wr_en,
    input  wire [1:0]  cfg_kernel_idx,    // Destination bank
    input  wire [3:0]  cfg_weight_addr,   // Weight index within the bank
    input  wire signed [7:0] cfg_weight_data,

    // Run-time control
    input  wire [1:0]  active_kernel_sel, // Bank driving the MAC array
    input  wire        relu_en,           // 1 = ReLU enabled

    // Input stream
    input  wire        valid_in,
    input  wire [7:0]  pixel_in,          // 8-bit unsigned grayscale

    // Output stream
    output wire        valid_out,
    output wire signed [15:0] pixel_out,  // 16-bit signed feature-map pixel
    output wire        kernel_ready       // 1 = selected kernel is loaded
);
```

### Operating Sequence

1. **Reset** — assert `rst_n` low, then release.
2. **Program weights** — write N² coefficients per bank by pulsing `cfg_wr_en` with `cfg_kernel_idx`, `cfg_weight_addr`, and `cfg_weight_data`.
3. **Select a kernel** — drive `active_kernel_sel`. The loader detects the change, deasserts `kernel_ready`, and copies the bank into the active weight register over N² cycles.
4. **Wait for `kernel_ready`** to return high.
5. **Stream pixels** — hold `valid_in` high and present one pixel per cycle in raster order.
6. **Collect outputs** — `pixel_out` is valid whenever `valid_out` is high, in raster order, `(W − N + 1) × (H − N + 1)` pixels per frame.

---

## Module Reference

### `top_cnn_accelerator.v`
Structural top level. Instantiates all five functional blocks, propagates parameters, and fixes the datapath latency constant (`CALC_LATENCY = 5`) that the control FSM uses for valid alignment.

### `control_fsm.v`
Tracks the raster position of the incoming stream and aligns the output valid signal with the datapath.

- Row and column counters sized with `$clog2` instead of fixed 16-bit registers, so counter width scales with the actual frame size.
- A window is valid only once `col_cnt ≥ KERNEL_DIM − 1` **and** `row_cnt ≥ KERNEL_DIM − 1`, which implements *valid* convolution with no padding.
- `valid_window` is pushed through a `DATAPATH_LATENCY`-deep shift register; the MSB becomes `valid_out`.
- `shift_en = valid_in | (|valid_pipeline)` — the datapath keeps clocking while data is still in flight, so the final pixels of a frame flush out correctly even after `valid_in` drops. When the pipeline is empty **and** no data is arriving, `shift_en` goes low and every register in the design stops toggling, which directly cuts dynamic power.

### `window_generator.v`
Builds the N×N sliding window with no BRAM.

- `KERNEL_DIM − 1` line buffers, each `IMAGE_WIDTH` bytes deep, tagged `(* shreg_extract = "yes" *)` so Vivado maps them to SRL16/SRL32 shift-register LUTs rather than distributed RAM or block RAM.
- An N×N register grid shifts left each cycle; the rightmost column is fed by the incoming pixel and the line-buffer taps.
- The grid is flattened into `window_flat` for a clean, parameterized interface to the PE array.
- No reset on the line buffers — this is deliberate, since a reset would prevent SRL inference and force the buffers into discrete flip-flops.

### `kernel_config_regs.v`
Programmable multi-kernel weight storage with a sequential loader.

- Weights live in a single flat `weight_mem` addressed by `{kernel_idx, weight_addr}`, which synthesizes into distributed LUT RAM.
- On a change of `active_kernel_sel`, a small FSM walks the selected bank one weight per cycle and shifts each byte into `active_weights_flat`:
  ```verilog
  active_weights_flat <= {weight_mem[rd_addr], active_weights_flat} >> 8;
  ```
  This is the main LUT optimization in the design: a naive implementation would need a `NUM_KERNELS`-to-1 multiplexer that is `KERNEL_DIM² × 8` bits wide (72 bits for 3×3, 200 bits for 5×5) plus per-byte address decoding. The shift-register loader replaces all of that steering logic with one 8-bit write port and a fixed shift.
- `kernel_ready` provides a handshake so the host never streams pixels against a half-loaded kernel.
- Cost of the trade: switching kernels takes N² cycles. For a streaming edge-AI workload where the kernel is set once per frame, this is free.

### `mac_unit.v`
One multiply element per kernel tap.

- The unsigned 8-bit pixel is explicitly zero-extended to 9 bits before the signed multiply, so no sign-interpretation bug is possible: `$signed({1'b0, pixel_in}) * weight_in`.
- `USE_DSP` selects between DSP48 inference (`use_dsp = "yes"` / `multstyle = "dsp"`) and forced fabric logic (`use_dsp = "no"` / `multstyle = "logic"`), with both Xilinx and Intel attributes present.
- The product register is gated by `shift_en`.
- Product range: 255 × −128 = −32,640 up to 255 × 127 = +32,385, which fits exactly in 16 signed bits.

### `pe_array.v`
N² parallel MACs plus a grouped, pipelined adder reduction.

- Products are summed in groups of `GROUP_SIZE` (default 3). Each group is a combinational adder chain followed by one pipeline register, and the group partials are then summed and registered again.
- `GROUP_SIZE` is an explicit area/frequency knob: a smaller value shortens the combinational path and raises F<sub>max</sub> at the cost of more registers (which are free in the FOM); a larger value reduces register count and shortens latency.
- The accumulator is 20 bits wide. For a 3×3 kernel the worst case is 9 × 32,640 = 293,760, which needs 20 signed bits; the width is carried at 20 bits throughout the reduction so no intermediate overflow is possible.

### `post_processing.v`
Saturation, optional ReLU, and output formatting.

- Range detection uses a sign-extension check rather than two 20-bit magnitude comparators:
  ```verilog
  wire in_range = (raw_sum[19:15] == {5{raw_sum[15]}});
  ```
  If the top five bits are all copies of bit 15, the value already fits in 16 signed bits and the low bits pass through untouched. Otherwise the sign bit alone decides between +32,767 and −32,768. This costs a handful of LUTs instead of a pair of wide comparators.
- ReLU, when enabled, forces negative results to zero **after** saturation, so a large negative accumulator still clamps cleanly to 0.
- The output is registered, adding the final cycle of the datapath latency.

---

## Pipeline Timing

| Stage | Register | Cycles |
|---|---|---|
| Window formation | `window_generator` grid | 1 |
| Multiply | `mac_unit.product_out` | 1 |
| Group reduction | `pe_array.group_partial_reg` | 1 |
| Final accumulation | `pe_array.raw_sum` | 1 |
| Saturation / ReLU | `post_processing.pixel_out` | 1 |
| **Total datapath latency** | | **5 cycles** |

`control_fsm` is instantiated with `DATAPATH_LATENCY = CALC_LATENCY = 5`, so `valid_out` is asserted exactly 5 cycles after the corresponding window becomes valid, keeping `pixel_out` and `valid_out` perfectly aligned.

- **Throughput:** 1 output pixel per cycle (sustained)
- **Latency to first output:** frame fill (`(N−1) × IMAGE_WIDTH + N` pixels) + 5 cycles
- **Outputs per frame:** `(IMAGE_WIDTH − N + 1) × (IMAGE_HEIGHT − N + 1)`

> **Note for anyone writing a reference model:** `pixel_out` is a *registered* output that samples the saturation logic on the previous clock edge. Any cycle-accurate model must include this one-cycle offset or every comparison will be off by one sample.

---

## Repository Structure

```
CNN_Accelerator/
├── RTL/                              Synthesizable Verilog source
│   ├── top_cnn_accelerator.v         Top-level integration
│   ├── control_fsm.v                 Counters, shift_en, valid alignment
│   ├── window_generator.v            N×N sliding window (SRL line buffers)
│   ├── kernel_config_regs.v          Multi-bank weights + sequential loader
│   ├── pe_array.v                    N² MACs + grouped adder reduction
│   ├── mac_unit.v                    Single signed×unsigned multiply element
│   └── post_processing.v             Saturation + optional ReLU
│
├── testbenches/                      Self-checking testbenches
│   ├── tb_top_cnn_accelerator.v          8×8 image, 3×3 kernel
│   ├── tb_top_cnn_accelerator_32x32.v    32×32 image, 3×3 kernel (spec size)
│   ├── tb_top_cnn_accelerator_4x4.v      10×10 image, 4×4 kernel
│   ├── tb_top_cnn_accelerator_5x5.v      10×10 image, 5×5 kernel
│   ├── tb_control_fsm.v
│   ├── tb_window_generator.v
│   ├── tb_kernel_config_regs.v
│   ├── tb_pe_array.v
│   ├── tb_mac_unit.v
│   └── tb_post_processing.v
│
├── Golden_Model/                     MATLAB reference model + test vectors
│   ├── run_golden_model.m            Golden model, vector export, figures
│   ├── input_pixels_dec.txt          64 input pixels, decimal
│   ├── input_pixels_hex.txt          64 input pixels, hex ($readmemh)
│   ├── expected_outputs_dec.txt      36 expected outputs, signed decimal
│   ├── expected_outputs_hex.txt      36 expected outputs, 16-bit hex
│   └── SSCS 2026 CNN Accelerator.png Golden-model visualization
│
├── Scripts/
│   └── run.do                        ModelSim/Questa compile + wave script
│
├── Architecture Block Diagram/
│   └── Architecture Block Diagram.png
│
└── TB_Pictures/                      Simulation waveform and console captures
```

---

## Getting Started

### Requirements

- **Simulation:** ModelSim / Questa (scripted), or Icarus Verilog / Vivado Simulator
- **Synthesis:** AMD/Xilinx Vivado
- **Golden model:** MATLAB
- **Target device:** AMD/Xilinx Zynq-7000 **XC7Z020** (PYNQ-Z2)

### Simulate with ModelSim / Questa

From the `Scripts/` directory:

```tcl
do run.do
```

`run.do` compiles all of `RTL/` and `testbenches/`, elaborates `tb_top_cnn_accelerator_32x32`, sets up grouped waveforms for control, configuration, and stream signals, and runs to completion.

To run a different top-level test, change the `vsim` line in `run.do` to the desired testbench module name.

### Simulate with Icarus Verilog

```bash
iverilog -o sim_32x32 RTL/*.v testbenches/tb_top_cnn_accelerator_32x32.v
vvp sim_32x32
```

### Synthesize with Vivado

```tcl
read_verilog [glob RTL/*.v]
synth_design -top top_cnn_accelerator -part xc7z020clg400-1
opt_design
place_design
route_design
report_utilization -file utilization.rpt
report_timing_summary -file timing.rpt
report_power -file power.rpt
```

For accurate FOM power, generate a SAIF from a post-implementation simulation and read it before running `report_power`:

```tcl
read_saif accelerator.saif
report_power -file power_saif.rpt
```

---

## Verification

### Top-Level Tests

| Testbench | Image | Kernel | Expected outputs | Purpose |
|---|---|---|---|---|
| `tb_top_cnn_accelerator.v` | 8×8 | 3×3 | 36 | Baseline integration, matches golden-model vectors |
| `tb_top_cnn_accelerator_32x32.v` | 32×32 | 3×3 | 900 | Competition-mandated minimum frame size |
| `tb_top_cnn_accelerator_4x4.v` | 10×10 | 4×4 | 49 | Kernel parameterization |
| `tb_top_cnn_accelerator_5x5.v` | 10×10 | 5×5 | 36 | Kernel parameterization |

Each top-level test exercises the full sequence: program weights → switch banks → wait on `kernel_ready` → stream a frame → flush → check that the exact expected number of valid output pixels was produced.

The `kernel_ready` handshake is tested deliberately. Every top-level testbench starts with `active_kernel_sel = 2'b11` and then switches to bank 0, which forces the loader FSM to run and guarantees the test cannot race past a stale `kernel_ready` left high from the reset-time load.

### Module-Level Tests

`testbenches/` also contains self-checking testbenches for each block — `tb_mac_unit.v`, `tb_window_generator.v`, `tb_kernel_config_regs.v`, `tb_pe_array.v`, `tb_post_processing.v`, and `tb_control_fsm.v` — covering multiply edge cases (255 × −128, 255 × 127), spatial window alignment, multi-bank weight storage, adder-tree accumulation, saturation and ReLU behavior, and valid-count/backpressure timing.

Simulation waveforms and console transcripts for all tests are captured in [`TB_Pictures/`](TB_Pictures/).

---

## Golden Reference Model

`Golden_Model/run_golden_model.m` is the independent MATLAB reference implementation used to prove functional correctness.

It performs a *valid* (no padding) 2-D convolution in double precision, then applies the same saturation and ReLU semantics as the RTL, and exports the resulting stream in four formats so the testbench can consume it directly with `$readmemh` or plain decimal comparison.

**Default test case:**

| Item | Value |
|---|---|
| Input image | 8×8, pixel values 1…64 in raster order |
| Kernel | 3×3, all zeros except center = 2 (scaled identity) |
| ReLU | Disabled |
| Expected outputs | 36 pixels (6×6 output map) |
| First outputs | 20, 22, 24, 26, 28, … |

The scaled-identity kernel is chosen as the primary test because it makes every output independently predictable by hand (`output = 2 × center pixel`), so any window-alignment or off-by-one error in the line buffers shows up immediately rather than being masked by a sum of nine terms.

The script also renders a four-panel verification figure — input image, kernel, output feature map, and the output valid stream — with per-cell numeric overlays:

![Golden Model Verification](Golden_Model/SSCS%202026%20CNN%20Accelerator.png)

**To regenerate the vectors:**

```matlab
cd Golden_Model
run_golden_model
```

Adjust `img_w`, `img_h`, `k_dim`, `kernel`, and `relu_en` at the top of the script to build new test cases.

---

## Implementation Results

Target device: **XC7Z020-1CLG400** (PYNQ-Z2), configuration `IMAGE_WIDTH = 32`, `IMAGE_HEIGHT = 32`, `KERNEL_DIM = 3`, `NUM_KERNELS = 4`, `USE_DSP = "YES"`.

| Parameter | Specification | Team Result | Units | Comments |
|---|---|---|---|---|
| Input image size | ≥ 32×32 | 32×32 (parameterized) | pixels | Larger sizes supported via parameters |
| Input precision | Unsigned fixed-point | 8 | bits | Full 0–255 grayscale range |
| Kernel precision | 8-bit signed | 8 | bits | −128 to +127 |
| Architecture type | — | Streaming, fully pipelined | — | Sliding window, stride 1, valid convolution |
| Multipliers / MACs | — | 9 | DSP48 | One per kernel tap |
| Pipeline stages | — | 5 | stages | See [Pipeline Timing](#pipeline-timing) |
| Latency | — | *TBD* | cycles | Frame fill + 5 |
| Throughput | — | **1.0** | pixel/cycle | Sustained after fill |
| LUTs | — | *TBD* | — | |
| FFs | — | *TBD* | — | Not penalized by the FOM |
| DSPs | — | 9 | — | |
| BRAMs | — | **0** | — | SRL-based line buffers |
| Maximum frequency | — | *TBD* | MHz | |
| Timing status | — | *TBD* | — | |
| Power estimate | — | *TBD* | W | SAIF-based, post-implementation |
| Verification status | — | Passed | — | Bit-exact vs. MATLAB golden model |
| **FOM** | — | *TBD* | — | Throughput / (Power × (LUTs + 50·DSPs + 100·BRAMs)) |

*Fill in the TBD entries from `utilization.rpt`, `timing.rpt`, and `power_saif.rpt` after implementation.*

---

## Design Decisions and Trade-offs

**DSP multipliers instead of LUT multipliers.**
The FOM charges 50 LUT-equivalents per DSP, so DSPs only pay off if each one saves more than 50 LUTs. This was measured, not assumed: building the design with `USE_DSP = "NO"` moves all nine multipliers into fabric and costs roughly 500 additional LUTs — about 55 LUTs per DSP, above the break-even point. DSP inference is therefore the FOM-optimal choice, and the `USE_DSP` parameter is kept so the experiment can be reproduced on any target device.

**Reducing MAC count is not an option.**
Sharing multipliers across cycles would cut DSP usage but divide throughput by the same factor, while the denominator only shrinks partially (LUTs and power for the control overhead go *up*). The net effect on the FOM is negative, so the array stays fully parallel at one MAC per tap.

**Zero BRAMs.**
A block RAM costs 100 LUT-equivalents in the denominator. Two 32-byte line buffers for a 3×3 window at 32-pixel width fit comfortably into SRL16 primitives, where each SRL holds 16 stages in a single LUT. The `shreg_extract` attribute forces this mapping, and the line buffers are intentionally left un-reset, because a reset on a shift-register chain blocks SRL inference and forces a fallback to discrete flip-flops.

**Flip-flops are free, so pipeline aggressively.**
The FOM denominator counts LUTs, DSPs, and BRAMs — not registers. Every pipeline register added to shorten a critical path raises F<sub>max</sub> and therefore throughput per second at literally zero FOM cost. This is why the design uses five register stages rather than a shallower, slower datapath.

**Sequential kernel loading instead of a wide bank mux.**
See [`kernel_config_regs.v`](#kernel_config_regsv) above. Trading a `NUM_KERNELS`-wide, `8·N²`-bit multiplexer for an N²-cycle load sequence removes a substantial block of steering LUTs, at a cost that is invisible in a streaming workload where the kernel changes at most once per frame.

**Cheap saturation.**
Comparing a 20-bit accumulator against +32,767 and −32,768 with explicit comparators costs two wide comparator chains. Checking that the top five bits are all equal to the sign bit achieves the same result with a 5-input equality test.

**Clock-enable gating for power.**
A single `shift_en` derived from `valid_in` OR-ed with the pipeline occupancy drives the enable of every register in the datapath. Between frames, or whenever the input stalls, the entire design stops toggling. Because the FOM divides by power, this directly improves the score, and it costs almost nothing in logic.

**SAIF-based power estimation.**
Vivado's vectorless power estimator assumes a default toggle rate on every net, which overstates activity for a design that idles between frames and carries correlated image data. Reading a SAIF captured from post-implementation simulation reports the activity the design actually exhibits, giving a more accurate — and lower — power figure in the FOM denominator.

---

## Bonus Features

| Bonus item | Status |
|---|---|
| One-output-pixel-per-cycle pipelined architecture | ✅ Implemented |
| Support for multiple kernels | ✅ 4 runtime-selectable banks with `kernel_ready` handshake |
| ReLU activation | ✅ Runtime-selectable via `relu_en` |
| Edge-detection demo | ⬜ Planned (Sobel kernels load directly into any bank) |
| Board demonstration | ⬜ Planned (PYNQ-Z2) |

---

## Assumptions

Per instruction 4 of the competition brief, the assumptions made in this design are stated explicitly:

1. **Valid convolution, no padding.** Output dimensions are `(W − N + 1) × (H − N + 1)`. Zero-padding was not required by the specification and would add boundary-detection logic and LUTs without improving the FOM.
2. **Raster-order streaming.** Pixels arrive row by row, left to right. The line-buffer depth is tied to `IMAGE_WIDTH`, so the frame width must match the synthesized parameter.
3. **Kernel programming precedes streaming.** Weights are not double-buffered against the active stream; the host waits for `kernel_ready` before asserting `valid_in`. Switching kernels mid-frame is not supported.
4. **No output backpressure.** The output side is assumed always ready. The design accepts input backpressure (deasserting `valid_in` stalls the datapath cleanly), but does not implement an output-side ready signal, which would add handshake logic for no FOM benefit.
5. **20-bit accumulator.** Sized for the 3×3 worst case (9 × 255 × 128 = 293,760). Kernels larger than 5×5 with full-scale weights would need a wider accumulator.
6. **Single channel.** Grayscale / single-feature-map input, as specified.

---

## License

Not yet specified. Add a `LICENSE` file if you intend to make the repository public.

---

## Acknowledgements

Developed for the **IEEE Solid-State Circuits Society (SSCS) Egypt Chapter — 2026 Student Design Competition**.
