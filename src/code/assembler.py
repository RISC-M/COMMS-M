from dataclasses import dataclass
from io import SEEK_SET
import sys
from enum import Enum


@dataclass
class FunctionUnit:
    name: str
    in_busses: tuple[int]
    out_busses: tuple[int]


class Direction(Enum):
    IN = 0
    OUT = 1
    BIDI = 2


@dataclass
class FUPort:
    fu: FunctionUnit
    direction: Direction
    address: int


if_fu = FunctionUnit("ifetch", (0, 1), (1, 2))
rf_fu = FunctionUnit("register_file", (0, 1, 2, 3), (0, 1, 2, 3))
int_fu = FunctionUnit("int", (0, 1), (1, 2))
imm_fu = FunctionUnit("immediate", tuple(), (0, 1, 2, 3))

port_mapping: dict[str, FUPort] = {
    "Tpc": FUPort(if_fu, Direction.IN, 8),
    "Tpcr": FUPort(if_fu, Direction.IN, 9),
    "Rpc": FUPort(if_fu, Direction.OUT, 8),
    "Oint": FUPort(int_fu, Direction.IN, 10),
    "Tadd": FUPort(int_fu, Direction.IN, 11),
    "Rint": FUPort(int_fu, Direction.OUT, 9),
}

for i in range(8):
    port_mapping[f"r{i}"] = FUPort(rf_fu, Direction.BIDI, i)


class Condition(Enum):
    NO_COND = 0
    COND_TRUE = 3
    COND_FALSE = 1


@dataclass
class Instr:
    source: int
    dest: int
    condition: Condition = Condition.NO_COND


def normalize_line(line: str) -> list[str]:
    comment_start = line.find("//")
    if comment_start != -1:
        return line[:comment_start].split()
    return line.split()


def assemble_code(in_name: str, out_name: str):
    in_f = open(in_name, "r")
    out_f = open(out_name, "wb")

    symbol_table: dict[int, str] = {}
    machine_code = []

    # Generate symbol table
    pc = 0
    for line in in_f:
        line = normalize_line(line)
        if len(line) == 0:
            continue
        if len(line) == 1:
            assert line[0][-1] == ":", "symbol definitions must end in a colon"
            symbol = line[0][:-1]
            if symbol in port_mapping:
                print("Error: cannot name a symbol the same as a port")
                exit(1)
            symbol_table[symbol] = pc
            continue
        assert len(line) == 4
        pc += 1

    in_f.seek(0, SEEK_SET)

    for line in in_f:
        code_line = []
        codes = normalize_line(line)

        if len(codes) in (0, 1):
            continue

        assert len(codes) == 4
        for bus, code in enumerate(codes):
            if code == "noop":
                code_line.append(Instr(0, 0))
                continue
            source, dest = code.split("->")
            instr = Instr(0, 0)
            if dest[-1] == "?":
                instr.condition = Condition.COND_TRUE
                dest = dest[:-1]
            elif dest[-1] == "!":
                instr.condition = Condition.COND_FALSE
                dest = dest[:-1]

            if source.isdecimal():
                port_source = FUPort(imm_fu, Direction.OUT, int(source) | (1 << 6))
            elif source in symbol_table:
                symbol_val = symbol_table[source]
                if symbol_val < -(2**5) or symbol_val >= 2**5:
                    print(
                        f"Error: {symbol_val} does not fit in 6 bits, {source}->{dest}"
                    )
                port_source = FUPort(
                    imm_fu, Direction.OUT, (symbol_table[source]) | (1 << 6)
                )
            elif source.removesuffix("+") in symbol_table:
                relative_val = symbol_table[source[:-1]] - len(machine_code) - 1
                if relative_val < -(2**5) or relative_val >= 2**5:
                    print(
                        f"Error: {relative_val} does not fit in 6 bits, {source}->{dest}"
                    )
                port_source = FUPort(
                    imm_fu,
                    Direction.OUT,
                    relative_val | (1 << 6),
                )
            else:
                port_source = port_mapping[source]

            port_dest = port_mapping[dest]

            if port_source.direction not in (Direction.OUT, Direction.BIDI):
                print(f"Error: {source} not a valid source port")
                exit(1)
            if port_dest.direction not in (Direction.IN, Direction.BIDI):
                print(f"Error: {source} not a valid destination port")
                exit(1)

            if bus not in port_source.fu.out_busses:
                print(f"Error: {source} not readable on bus {bus}")
                exit(1)
            if bus not in port_dest.fu.in_busses:
                print(f"Error: {source} not writeable on bus {bus}")
                exit(1)

            instr.source = port_source.address
            instr.dest = port_dest.address
            code_line.append(instr)
        machine_code.append(code_line)

    for instr in machine_code:
        for sub in instr:
            low_byte = sub.source & 0b1111111
            low_byte |= (sub.dest & 1) << 7
            high_byte = (sub.dest & 0b1111111) >> 1
            high_byte |= (sub.condition.value) << 6
            out_f.write(bytes((low_byte, high_byte)))
    out_f.close()
    in_f.close()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"{sys.argv[0]} assemble_file code_file")
        exit(1)

    in_name = sys.argv[1]
    out_name = sys.argv[2]
    assemble_code(in_name, out_name)
