"""Normaliza logs de Flutter para diagnóstico.

Uso:
    python analyze.py [project_dir] < log.txt   # analiza un log pegado
    python analyze.py [project_dir]             # ejecuta flutter analyze

Salida: JSON por stdout con exit_code, stdout, stderr y summary.
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Formatos reales de Flutter: "file:42:7: Error: ..." y "error • message • path:1:2"
SEVERITY_RE = re.compile(r"\b(error|warning|info)\b\s*[:(•]", re.IGNORECASE)


def resolve_root() -> Path:
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).expanduser().resolve()
    return Path.cwd()


def read_stdin() -> str:
    # En consola interactiva no hay stdin útil: evita bloquearse esperando EOF.
    if sys.stdin is None or sys.stdin.isatty():
        return ""
    return sys.stdin.read()


def run_flutter_analyze(root: Path) -> dict:
    exe = shutil.which("flutter") or shutil.which("flutter.bat")
    if not exe:
        return {
            "exit_code": None,
            "stdout": "",
            "stderr": "flutter no está en PATH",
        }

    cmd = [exe, "analyze"]
    # En Windows `flutter` es un .bat y no se puede ejecutar directo sin shell.
    if exe.lower().endswith(".bat"):
        cmd = ["cmd", "/c", *cmd]

    try:
        result = subprocess.run(
            cmd,
            cwd=str(root),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        return {
            "exit_code": None,
            "stdout": "",
            "stderr": "timeout ejecutando flutter analyze (300s)",
        }
    except OSError as exc:
        return {"exit_code": None, "stdout": "", "stderr": f"error al ejecutar flutter: {exc}"}

    return {
        "exit_code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


def summarize(text: str) -> dict:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]

    buckets = {"error": [], "warning": [], "info": []}
    for line in lines:
        match = SEVERITY_RE.search(line)
        if match:
            buckets[match.group(1).lower()].append(line)

    return {
        "total_lines": len(lines),
        "error_count": len(buckets["error"]),
        "warning_count": len(buckets["warning"]),
        "info_count": len(buckets["info"]),
        "errors": buckets["error"][:50],
        "warnings": buckets["warning"][:50],
        "infos": buckets["info"][:50],
    }


def main() -> None:
    root = resolve_root()
    pasted = read_stdin()

    if pasted.strip():
        result = {"exit_code": None, "stdout": pasted, "stderr": ""}
    else:
        result = run_flutter_analyze(root)

    result["root"] = str(root)
    result["summary"] = summarize(result.get("stdout") or "")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
