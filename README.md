# 4-bit Array Multiplier: RTL to GDSII (SKY130, open-source tools)

**Name:** Rashi Pandey, Gauri Krishnan
**Roll number:** 2026702015, 2024102073
**Course:** Digital VLSI, final assignment
**Process / library:** SkyWater SKY130, `sky130_fd_sc_hd` (typical corner `tt_025C_1v80` for Parts B and C)

A 4-bit unsigned array multiplier (16 AND gates, 12 full adders, 16 flip-flops, latency 2 cycles)
taken from Verilog RTL to a GDSII layout with Icarus Verilog, GTKWave, Yosys, OpenSTA and LibreLane
(OpenROAD, Magic, KLayout, Netgen), all from the IIC-OSIC-TOOLS Docker image.

## Results summary

| Part | Result |
|---|---|
| A: RTL simulation | `PASS: 256 vectors checked, 0 errors` |
| A: error test (`sum = a ^ b`) | `FAIL: 256 vectors checked, 95 errors` |
| B: synthesis | 63 cells, 16 flip-flops, 740.71 um^2, flip-flops 54.05 % of area |
| B: netlist simulation | `PASS: 256 vectors checked, 0 errors` |
| C: STA (T = 10 ns) | worst slack 7.396 ns, T_min = 2.604 ns, F_max = 384.0 MHz |
| C: critical path | `a_r[1]` to `p[6]`, 8 combinational cells |
| D: LibreLane (final run) | CLOCK_PERIOD = 7.0 ns, worst slack +0.585 ns, DRC 0, LVS 0 |
| D: layout | 1901 cells after P&R, core area 17759.5 um^2, wirelength 2405 um |

## Repository structure

```
mult4_2026702015/
|-- README.md
|-- rtl/    full_adder.v, mult_array.v
|-- tb/     tb_mult.v
|-- synth/  synth.tcl, mult_array_netlist.v, mult_array_stat.rpt
|-- sta/    sta.tcl, mult_array_timing.rpt
|-- pnr/    config.json, metrics.json, mult_array.gds
`-- report/ report.pdf
```

## Setup (Windows laptop)

PowerShell as Administrator, then restart:

```
wsl --install --no-distribution
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

WSL 2 did not start until Windows Security, Device security, Core isolation details,
Memory integrity was turned Off and the laptop was restarted.

Normal PowerShell:

```
wsl --status
docker run hello-world
Set-Content -Path "$HOME\.wslconfig" -Value "[wsl2]`nmemory=8GB`nprocessors=4"
wsl --shutdown
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudioCode -e
cd $HOME
git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git
cd iic-osic-tools
.\start_vnc.bat
```

After a restart, the container is started again with:

```
docker start iic-osic-tools_xvnc
```

Then open `http://localhost/vnc.html?password=abc123` in a browser and start a terminal.
Files live in `C:\Users\<user>\eda\designs` on Windows, which is `/foss/designs` in the container.

All commands below are run in the container terminal from the project folder, after:

```
cd /foss/designs/mult4_2026702015
sak-pdk sky130A
echo $PDK_ROOT $PDK $STD_CELL_LIBRARY
```

If `sak-pdk` is not found, set the variables by hand:

```
export PDK=sky130A
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=sky130_fd_sc_hd
```

The last command must print `/foss/pdks sky130A sky130_fd_sc_hd`.

Project folders and git (once):

```
mkdir rtl tb synth sta pnr report
git init
git config --global user.name "Rashi Pandey"
git config --global user.email "<your email>"
```

## Part A: RTL and verification

Files: `rtl/full_adder.v`, `rtl/mult_array.v`, `tb/tb_mult.v`.

```
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
```

Output: `PASS: 256 vectors checked, 0 errors`.

Error test: `sum` in `rtl/full_adder.v` was changed to `a ^ b`, then

```
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
```

Output: `FAIL: 256 vectors checked, 95 errors`. The change was undone with:

```
git checkout -- rtl/full_adder.v
```

Waveform:

```
gtkwave mult.vcd
```

My example is a = 5 + 5 = 10 and b = 7, so p = 70. b becomes 7 at 3370 ns, the inputs are captured at
the rising edge at 3375 ns, and p = 70 appears at the rising edge at 3385 ns (latency 2 cycles).

## Part B: synthesis (Yosys)

```
yosys -c synth/synth.tcl
cat synth/mult_array_stat.rpt
```

Netlist simulation:

```
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```

Output: `PASS: 256 vectors checked, 0 errors`.

The first gate-level run failed (239 errors) because the testbench read `p` 1 ns after the clock
edge, which races with the 1 ns cell delay. The testbench now reads `p` 4 ns after the edge.

## Part C: static timing analysis (OpenSTA)

```
sta -no_splash -exit sta/sta.tcl
```

With `create_clock -period 10` the worst slack is 7.396 ns, so T_min = 10 - 7.396 = 2.604 ns and
F_max = 1000 / 2.604 = 384.0 MHz. The critical path report is saved in `sta/mult_array_timing.rpt`:

```
grep -E "Startpoint|Endpoint|slack" sta/mult_array_timing.rpt
awk '/Startpoint: _095_/,0' sta/mult_array_timing.rpt
```

The period in `sta/sta.tcl` was then set to 2.60 ns and the command repeated:

```
sta -no_splash -exit sta/sta.tcl
```

Output: `worst slack max -0.00`.

## Part D: physical design (LibreLane)

`pnr/config.json` uses `DESIGN_NAME = "mult_array"`, `CLOCK_PORT = "clk"`, `FP_SIZING = "absolute"`,
`DIE_AREA = [0, 0, 150, 150]` and `CLOCK_PERIOD` as in the table below.

Start value: 1.2 x T_min = 1.2 x 2.604 = 3.125 ns, rounded up to the next 0.5 ns = 3.5 ns.
The environment variables must be set to `sky130A` first (see Setup). For each run:

```
cd pnr
sed -i 's/"CLOCK_PERIOD": *[0-9.]*/"CLOCK_PERIOD": <value>/' config.json
grep CLOCK_PERIOD config.json
echo $PDK_ROOT $PDK $STD_CELL_LIBRARY
librelane config.json
R=$(ls -d runs/RUN_* | tail -1); echo $R
grep -iE "setup__ws\"|route__drc_errors\"|lvs_error__count|instance__count\"|core__area|wirelength" $R/final/metrics.json
```

### CLOCK_PERIOD attempts (all with sky130A)


| Run | CLOCK_PERIOD (ns) | Worst setup slack (ns) | Result |
|---|---|---|---|
| 1 | 3.5 | -2.129 | failed |
| 2 | 4.0 | -1.629 | failed |
| 3 | 4.5 | -1.139 | failed |
| 4 | 5.0 | -0.642 | failed |
| 5 | 5.5 | -0.142 | failed |
| 6 | 6.0 | -0.064 | failed |
| 7 | 6.5 | +0.085 | passed, final |

All failures were in the slow corner `ss_100C_1v60`. Part C used only the typical corner
`tt_025C_1v80`, but LibreLane checks every corner. 
The runs made on 2026-10-23 used the wrong PDK (`ihp-sg13g2`, the default of the container) by mistake
and were discarded. The runs above were checked with:

```
grep -E '"PDK"|"STD_CELL_LIBRARY"|"CLOCK_PERIOD"' $R/resolved.json
grep -c "sky130_fd_sc_hd" $R/final/nl/mult_array.nl.v
grep -c "sg13g2" $R/final/nl/mult_array.nl.v
```

Final run results: 1901 cells after place and route (335 standard cells and 1566 fill cells; the
standard cells are 245 tap cells and 90 functional cells), core area 17759.5 um^2, wirelength 2405 um,
DRC 0, LVS 0, worst setup slack +0.585 ns, post-route F_max = 1000 / (7.0 - 0.585) = 155.9 MHz.

Files copied to the submission folder and layout viewed:

```
R=runs/RUN_2026-10-24_15-08-24
cp $R/final/metrics.json .
cp $R/final/gds/mult_array.gds .
klayout mult_array.gds
```

## Submission commands

```
cd /foss/designs/mult4_2026702015
git add .
git commit -m "<message>"
```

then in Windows PowerShell:

```
cd C:\Users\ASUS\eda\designs\mult4_2026702015
git push
```

The `runs/` folder is not committed (it is in `.gitignore`).

