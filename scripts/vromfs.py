import argparse
import shutil
import subprocess
from pathlib import Path

def copy_vromfs(src: Path, dst: Path) -> None:
  dst.mkdir(parents=True, exist_ok=True)
  for f in src.rglob("*.vromfs.bin"):
    out = dst / f.name
    shutil.copy2(f, out)

def unpack_vromfs(src: Path, dst: Path) -> None:
  tool = (Path(__file__).resolve().parent / "tools" / "vromfs.exe")
  if not tool.exists():
    raise SystemExit(1)
  for f in src.rglob("*.vromfs.bin"):
    name = f.name
    if name.endswith(".vromfs.bin"):
      base = name[: -len(".vromfs.bin")]
    else:
      base = f.stem
    out_dir = dst / base
    out_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(tool), "-U", str(f), str(out_dir)], check=True)

def main() -> None:
  parser = argparse.ArgumentParser()
  group = parser.add_mutually_exclusive_group(required=True)
  group.add_argument("-c", "--copy", nargs=2, type=Path)
  group.add_argument("-u", "--unpack", nargs=2, type=Path)
  args = parser.parse_args()

  if args.copy:
    src, dst = args.copy
    if not src.exists() or not src.is_dir():
      raise SystemExit(1)
    copy_vromfs(src, dst)
  elif args.unpack:
    src, dst = args.unpack
    if not src.exists() or not src.is_dir():
      raise SystemExit(1)
    unpack_vromfs(src, dst)


if __name__ == "__main__":
  main()