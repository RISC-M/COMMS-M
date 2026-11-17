import glob
from pathlib import Path

import cocotb
from cocotb.triggers import ReadWrite, Timer

from test_helpers import generate_runner, get_source_files
from src.code.assembler import assemble_code


def test_core_runner():
    generate_runner(
        __file__, get_source_files(__file__, ["core.sv"], []), "core", __name__
    )


async def generate_clock(dut):
    """Generate clock pulses."""

    while True:
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


def read_instr_mem(machine_code_file: str | Path) -> list[int]:
    byte_data = None
    with open(machine_code_file, "rb") as f:
        byte_data = f.read()
    assert (len(byte_data) & 0b111) == 0  # Len of file must be multiple of 8
    mem = []
    for i in range(0, len(byte_data), 8):
        # Read into an instruction little endian
        instr = 0
        instr |= byte_data[i] | (byte_data[i + 1] << 8)
        instr |= (byte_data[i + 2] | (byte_data[i + 3] << 8)) << 16
        instr |= (byte_data[i + 4] | (byte_data[i + 5] << 8)) << 32
        instr |= (byte_data[i + 6] | (byte_data[i + 7] << 8)) << 48
        mem.append(instr)
    len_pad = 8192 - len(mem)
    mem = mem + [0] * len_pad
    return mem


def get_test_files() -> list[tuple[str, str]]:
    code_dir = Path(__file__).parent / "code"
    tests = glob.glob("*.tta", root_dir=code_dir)

    cases = []

    for test in tests:
        assembly = code_dir / test
        test_file = assembly.parent / (assembly.stem + ".mc")
        assemble_code(assembly, test_file)

        answer_file = None
        answer_path = test_file.parent / (test_file.stem + ".correct")
        if answer_path.exists():
            answer_file = answer_path
        cases.append((test_file, answer_file))
    return cases


@cocotb.test()
@cocotb.parametrize(test_params=get_test_files())
async def test_ifetch_fu(dut, test_params: tuple[Path, Path | None]):
    machine_code_file, answer_file = test_params
    cocotb.start_soon(generate_clock(dut))

    await dut.clk.rising_edge
    await ReadWrite()

    imem = read_instr_mem(machine_code_file)

    dut.ifetch_fu_inst.instruction_mem.value = imem

    dut.rst_n.value = 0
    for i in range(2):
        await dut.clk.rising_edge
    await ReadWrite()
    dut.rst_n.value = 1

    for i in range(200):
        await dut.clk.rising_edge

    registers = dut.register_fu_inst.registers

    with open(machine_code_file.parent / (machine_code_file.stem + ".out"), "w") as f:
        for i in range(len(registers)):
            f.write(
                f"{i} = 0x{int(registers[i].value):08x} ({int(registers[i].value)})\n"
            )

    if answer_file is not None:
        with open(answer_file, "r") as f:
            for i, line in enumerate(f):
                val = int(line.split()[2], 16)
                assert registers[i].value == val, (
                    f"register[{i}] should be {val:08x} ({int(val)})"
                    f" it is set to {int(registers[i].value):08x} ({int(registers[i].value)})"
                )
