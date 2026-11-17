from dataclasses import dataclass
from io import SEEK_SET
import sys
from enum import Enum
import re


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


code_regex = (
    r"^((?P<source>[a-zA-Z]*)|(?P<number>-?[0-9]*))(?P<relative>\+)?(?P<index>\[[0-3]\])?(?P<cond>\!|\?)?"
    + r"->(?P<dest>r[0-7]|[a-zA-Z]*)"
)


if_fu = FunctionUnit("ifetch", (0, 1), (1, 2))
rf_fu = FunctionUnit("register_file", (0, 1, 2, 3), (0, 1, 2, 3))
int_fu = FunctionUnit("int", (0, 1), (1, 2))
imm_fu = FunctionUnit("immediate", tuple(), (0, 1, 2, 3))
big_imm_fu = FunctionUnit("big_imm", (0, 1, 2, 3), (0, 1))
comp_fu = FunctionUnit("comp", (0, 1, 2, 3), (1, 2))

port_mapping: dict[str, FUPort] = {
    "Tpc": FUPort(if_fu, Direction.IN, 8),
    "Tpcr": FUPort(if_fu, Direction.IN, 9),
    "Rpc": FUPort(if_fu, Direction.OUT, 8),
    "Oint": FUPort(int_fu, Direction.IN, 10),
    "Tadd": FUPort(int_fu, Direction.IN, 11),
    "Rint": FUPort(int_fu, Direction.OUT, 9),
    "Oimm": FUPort(big_imm_fu, Direction.IN, 12),
    "Rimm": FUPort(big_imm_fu, Direction.OUT, 10),
    "Tc_eq": FUPort(comp_fu, Direction.IN, 13),
    "Tc_ne": FUPort(comp_fu, Direction.IN, 14),
    "Tc_gt": FUPort(comp_fu, Direction.IN, 15),
    "Ocmp": FUPort(comp_fu, Direction.IN, 16),
    "Rcmp": FUPort(comp_fu, Direction.OUT, 11),
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
            instr = Instr(0, 0)

            matches = re.match(code_regex, code)

            if matches is None:
                print(f"Error: {code} is not a valid assembly instruction")
                exit(1)

            group_dict = matches.groupdict()
            numeric_value = None
            source_port = None

            if group_dict["number"]:
                numeric_value = int(group_dict["number"])
            elif group_dict["source"]:
                if group_dict["source"] in symbol_table:
                    numeric_value = symbol_table[group_dict["source"]]
                else:
                    source_port = port_mapping[group_dict["source"]]

            if group_dict["relative"]:
                if numeric_value is None:
                    print(
                        f"Error: Relative addressing must only be used with a constant or symbol, {code}"
                    )
                    exit(1)
                numeric_value = numeric_value - len(machine_code) - 1

            if group_dict["index"]:
                if numeric_value is None:
                    print(
                        f"Error: Indexing must only be used with a constant or symbol, {code}"
                    )
                    exit(1)

                index = int(group_dict["index"][1])
                numeric_value = (numeric_value >> (index * 6)) & ((1 << 6) - 1)

            if group_dict["cond"]:
                if group_dict["cond"] == "!":
                    instr.condition = Condition.COND_FALSE
                elif group_dict["cond"] == "?":
                    instr.condition = Condition.COND_TRUE
                else:
                    print(f"Error: {group_dict['cond']} is not a valid condition")
                    exit(1)

            if numeric_value is not None:
                if numeric_value < -(2**5) or numeric_value >= 2**6:
                    print(f"Error: {numeric_value} does not fit in 6 bits, {code}")
                    exit(1)
                source_port = FUPort(imm_fu, Direction.OUT, numeric_value | (1 << 6))

            dest_port = port_mapping[group_dict["dest"]]

            if source_port.direction not in (Direction.OUT, Direction.BIDI):
                print(f"Error: {code} does not have a valid source port")
                exit(1)
            if dest_port.direction not in (Direction.IN, Direction.BIDI):
                print(f"Error: {group_dict["dest"]} not a valid destination port")
                exit(1)

            if bus not in source_port.fu.out_busses:
                print(f"Error: {source_port.fu} not readable on bus {bus}")
                exit(1)
            if bus not in dest_port.fu.in_busses:
                print(f"Error: {dest_port.fu} not writeable on bus {bus}")
                exit(1)

            instr.source = source_port.address
            instr.dest = dest_port.address
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
