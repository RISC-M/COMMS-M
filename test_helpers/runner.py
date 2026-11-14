from pathlib import Path
from typing import Mapping

from cocotb_tools.runner import get_runner


def generate_runner(
    file: str,
    sources: list[Path],
    toplevel: str,
    module: str,
    parameters: Mapping[str, object] = None,
    waves_name: str | None = None,
):
    runner = get_runner("verilator")
    runner.build(
        sources=sources,
        hdl_toplevel=toplevel,
        waves=True,
        always=True,
        build_args=[
            "--trace-fst",
            "--trace-structs",
            "-F",
            str(Path(__file__).resolve().parent.parent / "verilator.vc"),
        ],
        parameters=parameters if parameters else {},
    )

    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True,
        test_args=[
            "--trace-file",
            f"../waves/{waves_name if waves_name else toplevel}.fst",
        ],
    )


def get_source_files(
    file: str, local_names: list[str], src_names: list[str]
) -> list[Path]:
    local_path = Path(file).resolve().parent

    paths = [local_path / name for name in local_names]

    path_parts = local_path.parts
    for i in range(len(path_parts) - 1, -1, -1):
        if path_parts[i] == "src":
            break

    src_path = Path("/".join(path_parts[: i + 1])).resolve()

    paths += [src_path / name for name in src_names]

    return paths
