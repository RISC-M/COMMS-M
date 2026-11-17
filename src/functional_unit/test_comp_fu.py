import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_comp_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["comp_fu.sv"], []),
        "comp_fu",
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
async def test_comp_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.in_addr_busses[0].value = 0
    dut.in_addr_busses[1].value = 3

    dut.out_addr_busses[0].value = 5
    dut.out_addr_busses[1].value = 5

    await dut.clk.rising_edge
    await ReadWrite()
    # Write operands to Tcmp_e Ocmp
    dut.in_busses[0].value = 5
    dut.in_busses[1].value = 10

    await dut.clk.rising_edge
    await ReadWrite()

    # Assert status bus is false
    assert dut.status_bus.value == 0

    # Write to Tcmp_e
    dut.in_busses[0].value = 10

    # Stop writing to ports
    dut.in_addr_busses[0].value = 5
    dut.in_addr_busses[1].value = 5

    dut.out_addr_busses[0].value = 0

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.status_bus.value == 1

    assert dut.out_busses[0].value == 1
    assert dut.busses_valid[0].value
