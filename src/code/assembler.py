from dataclasses import dataclass
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
    "Rpc": FUPort(if_fu, Direction.OUT, 8),
    "Oint": FUPort(int_fu, Direction.IN, 9),
    "Tadd": FUPort(int_fu, Direction.IN, 10),
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


def assemble_code(in_name: str, out_name: str):
    in_f = open(in_name, "r")
    out_f = open(out_name, "wb")

    machine_code = []

    for line in in_f:
        code_line = []
        codes = line.split()
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
