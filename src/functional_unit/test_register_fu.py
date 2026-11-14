import cocotb
from cocotb.triggers import ReadWrite, Timer
from test_helpers import generate_runner, get_source_files


def test_register_fu_runner():
    generate_runner(
        __file__,
        get_source_files(__file__, ["register_fu.sv"], []),
        "register_fu",
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
async def test_integer_fu(dut):
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    # Write to r0 on bus 0 and r1 on bus 1
    dut.waddr_busses[0].value = 0x0
    dut.waddr_busses[1].value = 0x1

    await dut.clk.rising_edge
    await ReadWrite()
    # 5 to address 0 and 10 to address 1
    dut.write_busses[0].value = 5
    dut.write_busses[1].value = 10

    # Clear write address
    dut.waddr_busses[0].value = 0x30
    dut.waddr_busses[1].value = 0x30

    # Read from r1 on bus 0 and r0 on bus 1
    dut.raddr_busses[0].value = 0x1
    dut.raddr_busses[1].value = 0x0

    await dut.clk.rising_edge
    await ReadWrite()

    assert dut.read_busses[0].value == 10
    assert dut.read_busses[1].value == 5
    assert dut.read_busses_valid[0].value
    assert dut.read_busses_valid[1].value
