import cocotb
from cocotb.triggers import ReadWrite, Timer, ReadOnly
from test_helpers import generate_runner, get_source_files


def test_in_port_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["in_port.sv"], []),
        "in_port",
        __name__,
        {"REGISTER_WITH_BYPASS": 0},
        "in_port_no_reg",
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def test_in_port(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.busses[0].value = 0xBEEFBEEF
    dut.busses[1].value = 0xCAFECAFE

    dut.addr_busses[0].value = 0x0
    dut.addr_busses[1].value = 0x1
    dut.condition_flags[0].value = 0b00

    await ReadOnly()
    assert dut.data_valid.value == 0

    await dut.clk.rising_edge
    await ReadWrite()

    dut.addr_busses[0].value = 0x1
    dut.addr_busses[1].value = 0x0

    await ReadOnly()

    assert dut.data.value == 0xBEEFBEEF
    assert dut.data_valid.value == 1

    await dut.clk.rising_edge
    await ReadWrite()
    dut.addr_busses[0].value = 0x1
    dut.addr_busses[1].value = 0x1
    await ReadOnly()

    assert dut.data.value == 0xCAFECAFE
    assert dut.data_valid.value == 1

    await dut.clk.rising_edge
    await ReadWrite()

    dut.condition_flags[1].value = 0b01
    dut.status_bus.value = 0
    dut.addr_busses[0].value = 0x1
    dut.addr_busses[1].value = 0x0

    await ReadOnly()
    assert dut.data_valid.value == 0

    await dut.clk.rising_edge
    await ReadWrite()
    assert dut.data_valid.value == 1
    assert dut.data.value == 0xCAFECAFE

    dut.condition_flags[1].value = 0b11
    dut.status_bus.value = 0

    await dut.clk.rising_edge
    await ReadOnly()
    assert dut.data_valid.value == 0
