"""兼容入口：运行当前版本的端到端验证脚本。"""

from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name("_verify.py")), run_name="__main__")
