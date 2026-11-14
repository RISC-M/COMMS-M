import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_immediate_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["immediate_fu.sv"], []),
        "immediate_fu",
        __name__,
        {"N": 2},
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def test_immediate_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.out_addr_busses[0].value = 0b1010101
    dut.out_addr_busses[1].value = 0b1101010

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.out_busses[0].value == 0b010101
    assert dut.out_busses[1].value == 0b101010

    assert dut.busses_valid[0].value
    assert dut.busses_valid[1].value

    dut.out_addr_busses[0].value = 0b0010101
    dut.out_addr_busses[1].value = 0b0101010

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.busses_valid[0].value == 0
    assert dut.busses_valid[1].value == 0
