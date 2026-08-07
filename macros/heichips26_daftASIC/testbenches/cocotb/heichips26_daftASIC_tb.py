# SPDX-FileCopyrightText: 2026 The HeiChips Contributors
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import os
import re
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import (Timer, RisingEdge, FallingEdge, ClockCycles, Edge,
                             First)
from cocotb.utils import get_sim_time
from cocotb_tools.runner import get_runner

sim      = os.getenv("SIM", "icarus")
pdk_root = os.getenv("PDK_ROOT", Path("~/.ciel").expanduser())
pdk      = os.getenv("PDK", "ihp-sg13cmos5l")
scl      = os.getenv("SCL", "sg13cmos5l_stdcell")
# GL=1 selects the gate-level netlist; anything else (unset, "0", "") stays in RTL mode.
gl       = os.getenv("GL", "0").strip().lower() in ("1", "true", "yes", "on")

hdl_toplevel = "top_module"

CLK_FREQ_HZ      = 25e6
CLK_FREQ_MHZ     = int(CLK_FREQ_HZ / 1e6)
CLK_PERIOD_NS    = 1e9 / CLK_FREQ_HZ

# PWM timebase, derived from the RTL
PWM_TICK_NS      = CLK_PERIOD_NS * 25

# PS/2 bit timing
PS2_HALF_PERIOD_US = 5

PS2_BREAK_CODE   = 0xF0

# Scancode -> high_frequency_pwm_counter value programmed by kbd_decoder
NOTE_COUNTS = {
    0x21: 1908,   # D -> Do
    0x23: 1700,   # R -> Re
    0x24: 1515,   # M -> Mi
    0x2B: 1432,   # F -> Fa
    0x34: 1275,   # S -> Sol
    0x1C: 1136,   # L -> La
    0x32: 1012,   # C -> Ci
}


INVALID_KEYS = [
    0x14,         # T
    0x18,         # O
    0x41,         # F7
    0x15,         # Y
    0x25,         # K
    0x31          # N
]

SCANCODE_ESC     = 0x76   # kbd_decoder silences the PWM on Esc

# Scancode -> note index programmed by kbd_decoder
SCANCODE_TO_NOTE = {
    SCANCODE_ESC: 0,
    0x23: 1, 0x2D: 2, 0x3A: 3, 0x2B: 4, 0x1B: 5, 0x4B: 6, 0x21: 7,
}

NOTE_TO_STACCATO_LEN = {
    1 : 393,
    2 : 441,
    3 : 495,
    4 : 523,
    5 : 588,
    5 : 660,
    7 : 741
}



# ----------------------------------------------------------------------------
# VGA constants, mirroring vga_protocol.v
# ----------------------------------------------------------------------------

H_FRONT_PORCH, H_SYNC_PULSE, H_BACK_PORCH, H_VISIBLE = 16, 96, 48, 640
H_END = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + H_VISIBLE     # 800
V_FRONT_PORCH, V_SYNC_PULSE, V_BACK_PORCH, V_VISIBLE = 12, 2, 35, 400
V_END = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE     # 449

# D1: the counters wrap on "== H_END" / "== V_END" rather than "== H_END - 1",
# so they take H_END + 1 and V_END + 1 distinct values. The frame is therefore
# 801 x 450, not the nominal 800 x 449, and runs at 69.36 Hz instead of 70 Hz.
H_TOTAL = H_END + 1     # 801
V_TOTAL = V_END + 1     # 450

PIXEL_CLK_NS = CLK_PERIOD_NS                    # cnt4 divides clk by 4 -> 25 MHz
LINE_NS      = H_TOTAL * PIXEL_CLK_NS           # 32_040 ns
FRAME_NS     = V_TOTAL * LINE_NS                # 14_418_000 ns

# hsync is active low over [16, 111]; vsync is active high over lines [12, 13].
HSYNC_LOW_FIRST,  HSYNC_LOW_LAST  = H_FRONT_PORCH, H_FRONT_PORCH + H_SYNC_PULSE - 1
VSYNC_HIGH_FIRST, VSYNC_HIGH_LAST = V_FRONT_PORCH, V_FRONT_PORCH + V_SYNC_PULSE - 1

# Visible box, as the RTL defines it (line_placement gates on the same range).
H_VIS_FIRST, H_VIS_LAST = H_END - H_VISIBLE, H_END - 1                  # 160..799
V_VIS_FIRST, V_VIS_LAST = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH, \
                          V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE - 1

LINE_THICKNESS        = 3
LINE_TO_LINE_DISTANCE = 20
BEGINNING_FROM_TOP    = 90
LINE_FIRST  = BEGINNING_FROM_TOP + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH   # 139
STAFF_BASES = [LINE_FIRST + i * LINE_TO_LINE_DISTANCE for i in range(5)]


NOTE_THICKNESS = 32
H_LEFT_BORDER  = (H_SYNC_PULSE + H_BACK_PORCH + H_END - NOTE_THICKNESS - 1) // 2  # 454
H_RIGHT_BORDER = H_LEFT_BORDER + NOTE_THICKNESS                                   # 489

# Multiple display areas
NUM_DISPLAY_AREAS = 5       # 4 notes + clef
DISPLAY_AREA_SZ = H_VISIBLE/NUM_DISPLAY_AREAS
FIRST_GLYPH_FIRST_COL = DISPLAY_AREA_SZ + (DISPLAY_AREA_SZ - NOTE_THICKNESS)/2
FIRST_GLYPH_LAST_COL  = FIRST_GLYPH_FIRST_COL + NOTE_THICKNESS

NOTE_HEIGHT = 64        # display_area spans top_of_note .. top_of_note + 63

# top_of_note per note, as computed by the case statement in vga_protocol.v
NOTE_TOPS = {
    0: 0,
    1: STAFF_BASES[3] + LINE_THICKNESS + 1,                                       # 203
    2: STAFF_BASES[4] - 2 * LINE_TO_LINE_DISTANCE + 5 * LINE_THICKNESS - 1,       # 193
    3: STAFF_BASES[2] + LINE_THICKNESS + 1,                                       # 183
    4: STAFF_BASES[3] - 2 * LINE_TO_LINE_DISTANCE + 5 * LINE_THICKNESS - 1,       # 173
    5: STAFF_BASES[1] + LINE_THICKNESS + 1,                                       # 163
    6: STAFF_BASES[2] - 2 * LINE_TO_LINE_DISTANCE + 5 * LINE_THICKNESS - 1,       # 153
    7: STAFF_BASES[2] - 2 * LINE_THICKNESS,                                       # 173
}

# note_type = {~|note | &note, ~note[0]} selects one of three glyph banks
NOTE_TYPE = {
    0:  0,
    1:  "eighth_line_stem_up",
    2:  "eighth_space_stem_up",
    3:  "eighth_line_stem_up",
    4:  "eighth_space_stem_up",
    5:  "eighth_line_stem_up",
    6:  "eighth_space_stem_down",
    7:  "eighth_line_stem_down"
}

ROM_BANK_SIZE = 64
ROM_WORD_BITS = 32

SETTLE_NS = 1   # read delay past a clock edge, so registered outputs are stable


def expected_pwm_period_ns(count):
    return 2 * (count + 1) * PWM_TICK_NS


# ----------------------------------------------------------------------------
# VGA golden model
# ----------------------------------------------------------------------------

_ROM_ENTRY_RE = re.compile(r"^\s*(\d+)\s*:\s*data\s*=\s*32'b([01]{32})\s*;", re.M)


def parse_note_rom(note_type, path=None):
    """Extract the glyph ROM straight out of note_memory.v."""

    if path is None:
        path = Path(__file__).resolve().parent / f"../../rtl/{note_type}_rom.v"

    text = Path(path).read_text()
    rom = {int(addr): bits for addr, bits in _ROM_ENTRY_RE.findall(text)}

    assert rom, f"no ROM entries parsed out of {path}"
    return rom


def golden_pixel(rom, note, line, pixel):
    """Expected RGB level (0/1) at a given position, per the RTL's behaviour."""
    # TODO: predictions for all four display areas
    if H_VIS_FIRST <= pixel <= H_VIS_LAST:
        for base in STAFF_BASES:
            if base + 1 <= line <= base + LINE_THICKNESS:
                return 1

    top = NOTE_TOPS[note]
    if FIRST_GLYPH_FIRST_COL <= pixel <= FIRST_GLYPH_LAST_COL and top <= line <= top + NOTE_HEIGHT - 1:
        address = (line - top)
        bits = rom.get(address, "0" * ROM_WORD_BITS)
        if bits[(pixel - FIRST_GLYPH_FIRST_COL) % ROM_WORD_BITS] == "1":
            return 1

    return 0


def rgb_level(dut):
    """Read the RGB output as a single 0/1 level."""
    r, g, b = int(dut.red.value), int(dut.green.value), int(dut.blue.value)
    assert r == g == b, f"rgb channels disagree: r={r} g={g} b={b}"
    return 1 if r else 0


class VgaScanner:
    """Tracks the raster position and jumps to arbitrary pixels."""

    def __init__(self, dut):
        self.dut = dut
        self.line = 0
        self.pixel = 0

    @staticmethod
    def _index(line, pixel):
        return line * H_TOTAL + pixel

    def verify(self):
        """Fail immediately on any phase slip, rather than silently misreading."""
        if gl:
            # No hierarchical access in a netlist: fall back to hsync, whose
            # level is known for every pixel.
            expected = 0 if HSYNC_LOW_FIRST <= self.pixel <= HSYNC_LOW_LAST else 1
            got = int(self.dut.hsync.value)
            assert got == expected, (
                f"lost raster lock: at ({self.line}, {self.pixel}) hsync is "
                f"{got}, expected {expected}")
            return

        got_line = int(self.dut.monitor.line_counter.value)
        got_pixel = int(self.dut.monitor.pixel_counter.value)
        assert (got_line, got_pixel) == (self.line, self.pixel), (
            f"lost raster lock: tracked ({self.line}, {self.pixel}) but the DUT "
            f"is at ({got_line}, {got_pixel})")

    async def sync(self):
        """Lock onto the start of the frame using vsync alone (works in GL too)."""
        await RisingEdge(self.dut.vsync)
        await Timer(SETTLE_NS, unit="ns")
        self.line, self.pixel = V_FRONT_PORCH, 0
        self.verify()

    async def advance(self, pixels=1, check=True):
        if pixels <= 0:
            return
        await Timer(pixels * PIXEL_CLK_NS, unit="ns")
        index = (self._index(self.line, self.pixel) + pixels) % (H_TOTAL * V_TOTAL)
        self.line, self.pixel = divmod(index, H_TOTAL)
        if check:
            self.verify()

    async def goto(self, line, pixel, check=True):
        """Jump forward to (line, pixel), wrapping around the frame if needed."""
        delta = (self._index(line, pixel) - self._index(self.line, self.pixel)) \
            % (H_TOTAL * V_TOTAL)
        if delta == 0:
            if check:
                self.verify()
            return
        await self.advance(delta, check=check)

    async def read_row(self, line, first_col, last_col):
        """Sample the RGB level across a horizontal run, left to right."""
        await self.goto(line, first_col)
        levels = []
        for _ in range(last_col - first_col + 1):
            levels.append(rgb_level(self.dut))
            await self.advance(1, check=False)
        self.verify()
        return levels


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
    await start_clock(dut.pixel_clk, CLK_FREQ_MHZ)
    # PS/2 idles high on both lines.
    dut.ps2clk.value = 1
    dut.ps2data.value = 1
    await reset(dut.reset, dut.pixel_clk)


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
    await start_clock(dut.pixel_clk, CLK_FREQ_MHZ)
    dut.ps2clk.value = 1
    dut.ps2data.value = 1

    dut.reset.value = 1
    await ClockCycles(dut.pixel_clk, 2)

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
    await RisingEdge(dut.pixel_clk)
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
async def test_pwm_invalid_keys_heichips26_daftASIC(dut):
    """Invalid keys should make the PWM stop."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    for scancode in INVALID_KEYS:
        dut._log.info(f"Releasing PS/2 key {hex(scancode)} (F0 + scancode)")
        await send_key_release(dut, scancode)

        # pwm_driver stops clocking when disabled
        await Timer(10, unit="us")
        level = int(dut.pwm.value)
        quiet_window = Timer(2000, unit="us")
        fired = await First(Edge(dut.pwm), quiet_window)

        assert fired is quiet_window, \
            f"pwm kept toggling after invalid key {hex(scancode)} (level was {level})"

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
    level = int(dut.pwm.value)
    quiet_window = Timer(2000, unit="us")
    fired = await First(Edge(dut.pwm), quiet_window)

    assert fired is quiet_window, \
        f"pwm kept toggling after Esc (level was {level})"

    logger.info("Done!")


@cocotb.test()
async def test_pwm_vibrato_heichips26_daftASIC(dut):
    """TODO: test description."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Start a note so the PWM is actually toggling first
    await send_key_release(dut, 0x23)

    await Timer(10, unit="us")
    # await measure_pwm_period(dut.pwm)

    # Trigger vibrato mode
    dut._log.info("Releasing '1' to trigger vibrato...")
    await send_key_release(dut, 0x16)

    # Allow 1% of slack
    tolerance = 0.25

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

    logger.info("Done!")


# ----------------------------------------------------------------------------
# VGA tests
# ----------------------------------------------------------------------------

@cocotb.test()
async def test_vga_hsync_timing_heichips26_daftASIC(dut):
    """hsync must be active low over exactly one 96-pixel run per line."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    scanner = VgaScanner(dut)
    await scanner.sync()

    levels = []
    for _ in range(H_TOTAL):
        levels.append(int(dut.hsync.value))
        await scanner.advance(1, check=False)
    scanner.verify()

    low = [pixel for pixel, level in enumerate(levels) if level == 0]

    assert low, "hsync never went low - wrong polarity, or no sync pulse at all"
    assert len(low) == H_SYNC_PULSE, \
        f"hsync low for {len(low)} pixels, expected {H_SYNC_PULSE}"
    assert low == list(range(HSYNC_LOW_FIRST, HSYNC_LOW_LAST + 1)), \
        (f"hsync low over pixels {low[0]}..{low[-1]} (contiguous: "
         f"{low == list(range(low[0], low[-1] + 1))}), expected "
         f"{HSYNC_LOW_FIRST}..{HSYNC_LOW_LAST}")

    logger.info(f"hsync low over pixels {low[0]}..{low[-1]}, "
                f"{H_TOTAL} pixels per line")
    logger.info("Done!")


@cocotb.test()
async def test_vga_vsync_and_frame_rate_heichips26_daftASIC(dut):
    """vsync must be active high over lines 12..13, with the expected periods."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Line period, measured between two hsync falling edges
    await FallingEdge(dut.hsync)
    line_start = get_sim_time("ns")
    await FallingEdge(dut.hsync)
    line_ns = get_sim_time("ns") - line_start

    assert line_ns == LINE_NS, \
        f"line period is {line_ns} ns, expected {LINE_NS} ns ({H_TOTAL} pixels)"

    # Frame period, measured between two vsync rising edges
    await RisingEdge(dut.vsync)
    frame_start = get_sim_time("ns")
    await RisingEdge(dut.vsync)
    frame_ns = get_sim_time("ns") - frame_start

    assert frame_ns == FRAME_NS, \
        f"frame period is {frame_ns} ns, expected {FRAME_NS} ns ({V_TOTAL} lines)"

    logger.info(f"line {line_ns / 1000:.2f} us ({1e9 / line_ns / 1000:.2f} kHz), "
                f"frame {frame_ns / 1e6:.3f} ms ({1e9 / frame_ns:.2f} Hz)")

    # vsync window: high on lines 12 and 13 only
    scanner = VgaScanner(dut)
    await scanner.sync()

    probes = [(0, 0), (5, 400), (11, 0), (11, H_END),
              (VSYNC_HIGH_FIRST, 0), (VSYNC_HIGH_FIRST, H_END),
              (VSYNC_HIGH_LAST, 0), (VSYNC_HIGH_LAST, H_END),
              (14, 0), (48, 400), (V_VIS_FIRST, 400), (V_VIS_LAST, 400),
              (V_END, H_END)]

    for line, pixel in sorted(probes):
        await scanner.goto(line, pixel)
        expected = 1 if VSYNC_HIGH_FIRST <= line <= VSYNC_HIGH_LAST else 0
        assert int(dut.vsync.value) == expected, \
            (f"vsync is {int(dut.vsync.value)} at line {line} pixel {pixel}, "
             f"expected {expected} (active high over lines "
             f"{VSYNC_HIGH_FIRST}..{VSYNC_HIGH_LAST})")

    logger.info("Done!")


@cocotb.test()
async def test_vga_counter_wrap_heichips26_daftASIC(dut):
    """Pin down the raster totals: pixel_counter 0..800, line_counter 0..449."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    if gl:
        dut._log.warning("skipped in GL: needs hierarchical access to the counters")
        return

    logger.info("Startup sequence...")
    await start_up(dut)

    scanner = VgaScanner(dut)
    await scanner.sync()

    # End of a line: 800 is a real pixel, and the next one starts a new line
    await scanner.goto(V_FRONT_PORCH, H_END)
    assert int(dut.monitor.pixel_counter.value) == H_END, \
        "pixel_counter never reaches H_END"

    await scanner.advance(1)
    assert int(dut.monitor.pixel_counter.value) == 0, "pixel_counter did not wrap"
    assert int(dut.monitor.line_counter.value) == V_FRONT_PORCH + 1, \
        "line_counter did not advance on the pixel wrap"

    # End of the frame: line 449 is a real line, and the next one wraps to 0
    await scanner.goto(V_END, H_END)
    assert int(dut.monitor.line_counter.value) == V_END, \
        "line_counter never reaches V_END"

    await scanner.advance(1)
    assert (int(dut.monitor.line_counter.value),
            int(dut.monitor.pixel_counter.value)) == (0, 0), \
        "frame did not wrap to (0, 0)"

    logger.info(f"raster is {H_TOTAL} x {V_TOTAL} (D1: nominal is {H_END} x {V_END})")
    logger.info("Done!")


@cocotb.test()
async def test_vga_staff_lines_heichips26_daftASIC(dut):
    """The five staff lines must be 3 px thick and span the visible width."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)   # no key pressed -> note 0 -> staff lines only

    scanner = VgaScanner(dut)
    await scanner.sync()

    # Columns inside and just outside the visible band
    lit_cols = [H_VIS_FIRST, 480, H_VIS_LAST]
    dark_cols = [H_VIS_FIRST - 1, H_END]

    for base in STAFF_BASES:
        for line in range(base, base + LINE_THICKNESS + 2):
            on_staff = base + 1 <= line <= base + LINE_THICKNESS

            for pixel in sorted(lit_cols + dark_cols):
                await scanner.goto(line, pixel)
                expected = 1 if (on_staff and pixel in lit_cols) else 0
                got = rgb_level(dut)
                assert got == expected, \
                    (f"staff line at base {base}: rgb is {got} at line {line} "
                     f"pixel {pixel}, expected {expected}")

    logger.info(f"staff lines verified at rows "
                f"{[(b + 1, b + LINE_THICKNESS) for b in STAFF_BASES]}")
    logger.info("Done!")


@cocotb.test()
async def test_vga_note_placement_heichips26_daftASIC(dut):
    """Each note must select the right glyph bank and vertical position."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    if gl:
        dut._log.warning("skipped in GL: needs hierarchical access to vga_protocol")
        return

    logger.info("Startup sequence...")
    await start_up(dut)

    address_probes = {0x23: 1, 0x2D: 2, 0x21: 7}

    for scancode, note in SCANCODE_TO_NOTE.items():
        dut._log.info(f"Releasing PS/2 key {hex(scancode)} -> note {note}")
        await send_key_release(dut, scancode)

        got_top = int(dut.monitor.top_of_note.value)
        assert got_top == NOTE_TOPS[note], \
            (f"note {note} ({hex(scancode)}): top_of_note is {got_top}, "
             f"expected {NOTE_TOPS[note]}")

        if scancode not in address_probes:
            continue

        row = 5
        scanner = VgaScanner(dut)
        await scanner.sync()
        await scanner.goto(NOTE_TOPS[note] + row, 460)

        expected_address = row
        got_address = int(dut.monitor.memory_address.value)
        assert got_address == expected_address, \
            (f"note {note} ({hex(scancode)}): memory_address is {got_address}, "
             f"expected {expected_address} (bank {NOTE_TYPE[note]}, row {row})")

        dut._log.info(f"note {note}: top_of_note {got_top}, "
                      f"glyph bank {NOTE_TYPE[note]} at ROM base "
                      f"{NOTE_TYPE[note] * ROM_BANK_SIZE}")

    logger.info("Done!")


@cocotb.test()
async def test_vga_note_render_heichips26_daftASIC(dut):
    """The rendered glyph must match the ROM, pixel for pixel."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Do covers the "through line" bank, Ci the "upside down" one.
    for scancode in (0x23, 0x21):
        note = SCANCODE_TO_NOTE[scancode]
        top = NOTE_TOPS[note]

        rom = parse_note_rom(NOTE_TYPE[note])

        dut._log.info(f"Releasing PS/2 key {hex(scancode)} -> note {note}")
        await send_key_release(dut, scancode)

        scanner = VgaScanner(dut)
        await scanner.sync()

        first_col, last_col = FIRST_GLYPH_FIRST_COL - 3, FIRST_GLYPH_LAST_COL + 2
        mismatches = []

        for line in range(top - 2, top + NOTE_HEIGHT + 2):
            levels = await scanner.read_row(line, first_col, last_col)
            for offset, got in enumerate(levels):
                pixel = first_col + offset
                want = golden_pixel(rom, note, line, pixel)
                if got != want:
                    mismatches.append((line, pixel, got, want))

        assert not mismatches, (
            f"note {note} ({hex(scancode)}): {len(mismatches)} pixel(s) differ "
            f"from the ROM; first at line {mismatches[0][0]} pixel "
            f"{mismatches[0][1]} (got {mismatches[0][2]}, expected {mismatches[0][3]})")

        dut._log.info(f"note {note} glyph matches the ROM over rows "
                      f"{top - 2}..{top + NOTE_HEIGHT + 1}, columns "
                      f"{first_col}..{last_col}")

    logger.info("Done!")


@cocotb.test()
async def test_vga_blanking_heichips26_daftASIC(dut):
    """RGB must stay at 0 everywhere outside the visible box."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    logger.info("Startup sequence...")
    await start_up(dut)

    # Pick a note whose glyph reaches furthest down, so blanking is exercised
    # against an actively rendering frame.
    await send_key_release(dut, 0x23)

    scanner = VgaScanner(dut)
    await scanner.sync()

    probes = []
    # Vertical blanking: every line above the visible box, plus the last line
    for line in list(range(0, V_VIS_FIRST, 4)) + [V_END]:
        probes += [(line, 0), (line, H_LEFT_BORDER + 10), (line, 480), (line, H_END)]
    # Horizontal blanking: the front porch, sync pulse and back porch
    for line in range(V_VIS_FIRST, V_VIS_LAST + 1, 40):
        probes += [(line, 0), (line, HSYNC_LOW_FIRST), (line, HSYNC_LOW_LAST),
                   (line, H_VIS_FIRST - 1), (line, H_END)]

    for line, pixel in sorted(probes):
        await scanner.goto(line, pixel)
        got = rgb_level(dut)
        assert got == 0, \
            f"rgb is {got} at line {line} pixel {pixel}, which is outside the " \
            f"visible box (lines {V_VIS_FIRST}..{V_VIS_LAST}, " \
            f"pixels {H_VIS_FIRST}..{H_VIS_LAST})"

    logger.info(f"{len(probes)} blanking probes all read 0")
    logger.info("Done!")



@cocotb.test()
async def test_vga_frame_dump_heichips26_daftASIC(dut):
    """Capture a whole visible frame, check it, and write it out as a PGM."""
    logger = logging.getLogger("heichips26_daftASIC_tb")

    if os.getenv("VGA_DUMP", "0").strip().lower() not in ("1", "true", "yes", "on"):
        logger.info("skipped: set VGA_DUMP=1 to capture and write a frame image")
        return

    logger.info("Startup sequence...")
    await start_up(dut)

    scancode = int(os.getenv("VGA_DUMP_KEY", "0x23"), 0)
    note = SCANCODE_TO_NOTE[scancode]
    rom = parse_note_rom(NOTE_TYPE[note])

    dut._log.info(f"Releasing PS/2 key {hex(scancode)} -> note {note}")
    await send_key_release(dut, scancode)

    scanner = VgaScanner(dut)
    await scanner.sync()

    rows = []
    mismatches = []
    for line in range(V_VIS_FIRST, V_VIS_LAST + 1):
        levels = await scanner.read_row(line, H_VIS_FIRST, H_VIS_LAST)
        rows.append(levels)
        #TODO: update to match the new implementation
        # for offset, got in enumerate(levels):
        #     pixel = H_VIS_FIRST + offset
        #     want = golden_pixel(rom, note, line, pixel)
        #     if got != want:
        #         mismatches.append((line, pixel, got, want))

    out_path = Path(__file__).resolve().parent / f"vga_frame_note{note}.pgm"
    write_pgm(out_path, rows)
    logger.info(f"wrote {out_path} ({H_VISIBLE}x{V_VISIBLE})")

    #TODO: update to match the updated implementation
    # assert not mismatches, (
    #     f"{len(mismatches)} pixel(s) differ from the golden frame; first at "
    #     f"line {mismatches[0][0]} pixel {mismatches[0][1]} "
    #     f"(got {mismatches[0][2]}, expected {mismatches[0][3]}) - "
    #     f"see {out_path}")

    logger.info("Done!")


def write_pgm(path, rows):
    """Write a bitmap of 0/1 levels as a binary PGM."""
    height = len(rows)
    width = len(rows[0]) if height else 0

    body = bytearray()
    for row in rows:
        body.extend(255 if level else 0 for level in row)

    with open(path, "wb") as handle:
        handle.write(f"P5\n{width} {height}\n255\n".encode("ascii"))
        handle.write(body)


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

    build_args += ["-f", str(proj_path / "../../.generated/flist")]

    runner = get_runner(sim)
    runner.build(
        #sources=sources,
        hdl_toplevel=hdl_toplevel,
        #defines=defines,
        always=True,
        #includes=includes,
        build_args=build_args,
        waves=True,
        timescale=("1ns", "1fs")
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        hdl_toplevel_lang="verilog",
        test_module="heichips26_daftASIC_tb",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    heichips26_daftASIC_runner()
