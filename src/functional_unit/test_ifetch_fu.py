from dataclasses import dataclass

import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_ifetch_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["ifetch_fu.sv"], []),
        "ifetch_fu",
        __name__,
        {"IN_N": 1, "OUT_N": 1, "PC_T": 1, "PC_R": 0},
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@dataclass
class Instr:
    source: int
    dest: int


def generate_instr(instr: list[Instr]) -> int:
    assert len(instr) == 4
    out = 0
    for idx, inst in enumerate(instr):
        inst_int = (inst.dest << 7) | inst.source
        out |= (inst_int) << (idx * 16)
    return out


@cocotb.test()
async def test_ifetch_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    imem = [0] * 8192
    imem[0] = generate_instr([Instr(1, 2), Instr(3, 4), Instr(5, 6), Instr(7, 8)])
    imem[1] = generate_instr([Instr(2, 1), Instr(4, 3), Instr(6, 5), Instr(8, 7)])

    dut.instruction_mem.value = imem
    dut.out_addr_busses[0].value = 0

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    assert dut.read_addr_busses[0].value == 1
    assert dut.read_addr_busses[1].value == 3
    assert dut.read_addr_busses[2].value == 5
    assert dut.read_addr_busses[3].value == 7

    assert dut.write_addr_busses[0].value == 2
    assert dut.write_addr_busses[1].value == 4
    assert dut.write_addr_busses[2].value == 6
    assert dut.write_addr_busses[3].value == 8

    assert dut.out_busses[0].value == 0

    dut.in_addr_busses[0].value = 1

    await dut.clk.rising_edge
    await ReadWrite()

    dut.in_busses[0].value = 10

    assert dut.read_addr_busses[0].value == 2
    assert dut.read_addr_busses[1].value == 4
    assert dut.read_addr_busses[2].value == 6
    assert dut.read_addr_busses[3].value == 8

    assert dut.write_addr_busses[0].value == 1
    assert dut.write_addr_busses[1].value == 3
    assert dut.write_addr_busses[2].value == 5
    assert dut.write_addr_busses[3].value == 7

    assert dut.out_busses[0].value == 1

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.out_busses[0].value == 10
