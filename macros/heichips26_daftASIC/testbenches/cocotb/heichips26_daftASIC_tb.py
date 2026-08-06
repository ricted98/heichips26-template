import os
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ClockCycles, Edge, First
from cocotb.utils import get_sim_time
from cocotb_tools.runner import get_runner

sim      = os.getenv("SIM", "icarus")
pdk_root = os.getenv("PDK_ROOT", Path("~/.ciel").expanduser())
pdk      = os.getenv("PDK", "ihp-sg13cmos5l")
scl      = os.getenv("SCL", "sg13cmos5l_stdcell")
# GL=1 selects the gate-level netlist; anything else (unset, "0", "") stays in RTL mode.
gl       = os.getenv("GL", "0").strip().lower() in ("1", "true", "yes", "on")

hdl_toplevel = "top_module"

CLK_FREQ_HZ      = 100e6
CLK_FREQ_MHZ     = int(CLK_FREQ_HZ / 1e6)
CLK_PERIOD_NS    = 1e9 / CLK_FREQ_HZ            # 10 ns

# PWM timebase, derived from the RTL
PWM_TICK_NS      = CLK_PERIOD_NS * 25

# PS/2 bit timing
PS2_HALF_PERIOD_US = 5

PS2_BREAK_CODE   = 0xF0

# Scancode -> high_frequency_pwm_counter value programmed by kbd_decoder
NOTE_COUNTS = {
    0x23: 1908,   # D -> Do
    0x2D: 1700,   # R -> Re
    0x3A: 1515,   # M -> Mi
    0x2B: 1432,   # F -> Fa
    0x1B: 1275,   # S -> Sol
    0x4B: 1136,   # L -> La
    0x21: 1012,   # C -> Ci
}

SCANCODE_ESC     = 0x76   # kbd_decoder silences the PWM on Esc

def expected_pwm_period_ns(count):
    return 2 * (count + 1) * PWM_TICK_NS


async def start_clock(clock, freq=CLK_FREQ_MHZ):
    """Start the clock @ freq MHz"""
    period_ns = round(1 / freq * 1000, 4)
    c = Clock(clock, period_ns, "ns")
    cocotb.start_soon(c.start())


async def reset(reset, clock, cycles=2):
    """Pulse the active-high reset for `cycles` clock cycles."""
    cocotb.log.info("Reset asserted...")

    reset.value = 1
    await ClockCycles(clock, cycles)
    reset.value = 0
    await RisingEdge(clock)

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Startup sequence: clock + reset, ps2 lines idle high."""
    await start_clock(dut.clk, CLK_FREQ_MHZ)
    # PS/2 idles high on both lines.
    dut.ps2clk.value = 1
    dut.ps2data.value = 1
    await reset(dut.reset, dut.clk)


async def send_ps2_packet(dut, data_byte):
    """Drive an 11-bit PS/2 frame into the DUT."""
    parity = 1 - (bin(data_byte).count('1') % 2)
    frame = (data_byte << 1) | (parity << 9) | (1 << 10)  # Start=0, Stop=1

    # Idle state
    dut.ps2clk.value = 1
    dut.ps2data.value = 1
    await Timer(2 * PS2_HALF_PERIOD_US, unit="us")

    half_period = PS2_HALF_PERIOD_US

    for i in range(11):
        # Data transition while the clock is still high
        dut.ps2data.value = (frame >> i) & 1
        await Timer(half_period, unit="us")

        # Clock low: this is the edge the DUT samples on
        dut.ps2clk.value = 0
        await Timer(half_period, unit="us")

        # Clock high
        dut.ps2clk.value = 1
        await Timer(half_period, unit="us")

    # Leave lines idle
    dut.ps2data.value = 1
    await Timer(2 * PS2_HALF_PERIOD_US, unit="us")


async def send_key_release(dut, scancode):
    """Send a full break sequence (F0 + scancode)."""
    await send_ps2_packet(dut, PS2_BREAK_CODE)
    await send_ps2_packet(dut, scancode)


async def measure_pwm_period(pwm_signal, skip=2):
    """Measure one full PWM period in ns."""
    for _ in range(skip):
        await RisingEdge(pwm_signal)

    await RisingEdge(pwm_signal)
    start_time = get_sim_time("ns")

    await RisingEdge(pwm_signal)
    end_time = get_sim_time("ns")

    return end_time - start_time


@cocotb.test()
async def test_reset_values_heichips26_daftASIC(dut):
    """Check output port values while reset is asserted."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_clock(dut.clk, CLK_FREQ_MHZ)
    dut.ps2clk.value = 1
    dut.ps2data.value = 1

    dut.reset.value = 1
    await ClockCycles(dut.clk, 2)

    assert dut.pwm.value == 0, \
        f"pwm not zero during reset (got {dut.pwm.value})"

    # hsync is combinational on pixel_counter and idles high
    assert dut.hsync.value == 1, \
        f"hsync not idle-high during reset (got {dut.hsync.value})"

    # vsync only pulses on lines 12..13
    assert dut.vsync.value == 0, \
        f"vsync not zero during reset (got {dut.vsync.value})"

    assert dut.red.value == 0 and dut.green.value == 0 and dut.blue.value == 0, \
        (f"rgb not blanked during reset (got r={dut.red.value} "
         f"g={dut.green.value} b={dut.blue.value})")

    dut.reset.value = 0
    await RisingEdge(dut.clk)
    logger.info("Done!")


@cocotb.test()
async def test_pwm_valid_keys_heichips26_daftASIC(dut):
    """Each note key must reprogram the PWM to its expected period."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Allow 1% of slack
    tolerance = 0.01

    for scancode, count in NOTE_COUNTS.items():
        expected_ns = expected_pwm_period_ns(count)

        dut._log.info(f"Releasing PS/2 key {hex(scancode)} (F0 + scancode)")
        await send_key_release(dut, scancode)

        dut._log.info("Measuring PWM period...")
        measured_ns = await measure_pwm_period(dut.pwm)

        dut._log.info(
            f"{hex(scancode)}: measured {measured_ns:.0f} ns "
            f"({1e9 / measured_ns:.1f} Hz), expected {expected_ns:.0f} ns "
            f"({1e9 / expected_ns:.1f} Hz)"
        )

        assert abs(measured_ns - expected_ns) <= tolerance * expected_ns, \
            (f"scancode {hex(scancode)}: measured PWM period {measured_ns:.0f} ns "
             f"is outside {tolerance:.0%} of the expected {expected_ns:.0f} ns")

    logger.info("Done!")


@cocotb.test()
async def test_pwm_silenced_heichips26_daftASIC(dut):
    """Esc clears high_frequency_pwm_enable, freezing the PWM output."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Start a note so the PWM is actually toggling first
    await send_key_release(dut, 0x23)
    await measure_pwm_period(dut.pwm)

    dut._log.info("Releasing Esc to silence the PWM")
    await send_key_release(dut, SCANCODE_ESC)

    # pwm_driver stops clocking when disabled
    await Timer(10, unit="us")
    level = dut.pwm.value
    quiet_window = Timer(2000, unit="us")
    fired = await First(Edge(dut.pwm), quiet_window)

    assert fired is quiet_window, \
        f"pwm kept toggling after Esc"

    logger.info("Done!")


def heichips26_daftASIC_runner():

    proj_path = Path(__file__).resolve().parent

    sources  = []
    defines  = {}
    includes = [proj_path / "../../rtl/"]

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "sg13cmos5l_udp.v")

        # TODO: Unpowered gate-level netlist of the macro
        # sources.append(proj_path / f"../../final/nl/{hdl_toplevel}.nl.v")
        # sources.append(proj_path / f"../../macros/heichips26_daftASIC/final/nl/heichips26_daftASIC.nl.v")

        # Unpowered netlist: USE_POWER_PINS must NOT be defined at all
        # (passing USE_POWER_PINS=False would still define the macro).
    else:
        sources.append(proj_path / "../../rtl/top_module.v")
        sources.append(proj_path / "../../rtl/cnt4.v")
        sources.append(proj_path / "../../rtl/cnt25.v")
        sources.append(proj_path / "../../rtl/kbd_protocol_modified.v")
        sources.append(proj_path / "../../rtl/kbd_decoder.v")
        sources.append(proj_path / "../../rtl/vga_protocol.v")
        sources.append(proj_path / "../../rtl/note_memory.v")
        sources.append(proj_path / "../../rtl/parallel_to_serial.v")
        sources.append(proj_path / "../../rtl/pwm_driver.v")

    build_args = []

    if sim == "icarus":
        # -gno-specify: skip specify blocks; sg13cmos5l_stdcell.v uses
        # `ifnone with edge-sensitive paths`, which iverilog can't parse.
        build_args = ["-DSIM", "-gno-specify"]

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        waves=True,
        timescale=("1ns", "1fs")
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="heichips26_daftASIC_tb",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    heichips26_daftASIC_runner()
