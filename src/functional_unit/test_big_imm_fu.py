import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_big_imm_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["big_imm_fu.sv"], []),
        "big_imm_fu",
        __name__,
        {"IN_N": 2},
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def test_big_imm_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.in_addr_busses[0].value = 0
    dut.in_addr_busses[1].value = 0

    await dut.clk.rising_edge
    await ReadWrite()

    dut.in_busses[0].value = 0b1110001
    dut.in_busses[1].value = 0b0001110

    dut.out_addr_busses[0].value = 0

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.out_busses[0].value == 0b00011101110001
    assert dut.busses_valid[0].value

    dut.in_busses[0].value = 0b1110001
    dut.in_busses[1].value = 0b1001110

    await dut.clk.rising_edge
    await ReadWrite()

    assert int(dut.out_busses[0].value) & ((1 << 14) - 1) == 0b10011101110001
    assert int(dut.out_busses[0].value) & ((1 << 14)) != 0
    assert dut.busses_valid[0].value
