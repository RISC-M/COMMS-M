import cocotb
from cocotb.triggers import ReadWrite, Timer, ReadOnly
from test_helpers import generate_runner, get_source_files


def test_out_port_runner():
    generate_runner(
        __file__, get_source_files(__file__, ["out_port.sv"], []), "out_port", __name__
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def test_out_port(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    dut.squash_line.value = 0

    dut.data.value = 0xBEEFBEEF
    dut.data_valid.value = 1

    dut.addr_busses[0].value = 0x0
    dut.addr_busses[1].value = 0x1

    await ReadOnly()
    assert dut.data_read.value == 1
    assert dut.busses_valid[0].value == 0
    assert dut.busses_valid[1].value == 0

    await dut.clk.rising_edge
    await ReadWrite()

    dut.addr_busses[0].value = 0x1
    dut.addr_busses[1].value = 0x0

    await ReadOnly()

    assert dut.busses[0].value == 0xBEEFBEEF
    assert dut.busses[1].value == 0xBEEFBEEF
    assert dut.busses_valid[0].value == 1
    assert dut.busses_valid[1].value == 0
    assert dut.data_read.value == 1

    await dut.clk.rising_edge
    await ReadOnly()

    assert dut.busses[0].value == 0xBEEFBEEF
    assert dut.busses[1].value == 0xBEEFBEEF
    assert dut.busses_valid[0].value == 0
    assert dut.busses_valid[1].value == 1
    assert dut.data_read.value == 1
