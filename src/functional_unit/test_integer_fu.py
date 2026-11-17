import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_integer_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["integer_fu.sv"], []),
        "integer_fu",
        __name__,
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def test_integer_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.in_addr_busses[0].value = 0x0
    dut.in_addr_busses[1].value = 0x1
    dut.condition_flags[0].value = 0
    dut.condition_flags[1].value = 0

    await dut.clk.rising_edge
    await ReadWrite()
    # Write operands to O and T port
    dut.in_busses[0].value = 5
    dut.in_busses[1].value = 10

    # Write address to out port
    dut.out_addr_busses[0].value = 0x2
    dut.out_addr_busses[1].value = 0x0

    # Write next cycle addresses to in ports
    dut.in_addr_busses[0].value = 0x0
    dut.in_addr_busses[1].value = 0x5
    await dut.clk.rising_edge
    await ReadWrite()

    # Assert correct sum is on output bus
    assert dut.out_busses[0].value == 15
    assert dut.busses_valid[0].value == 1

    # Write to trigger port with new data
    dut.in_busses[0].value = 10

    # Write next cycle addresses to in ports
    dut.in_addr_busses[0].value = 0x5
    dut.in_addr_busses[1].value = 0x5

    await dut.clk.rising_edge
    await ReadWrite()

    # Assert correct sum is on output bus
    assert dut.out_busses[0].value == 20
    assert dut.busses_valid[0].value == 1

    await dut.clk.rising_edge
    await ReadWrite()

    # Assert no sum is on output bus
    assert dut.busses_valid[0].value == 0
