"""Check local Markdown links, fences, and HCL syntax without cloud credentials.

HCL fragments are parsed separately. This does not resolve references, validate
provider schemas, or prove that a snippet can be planned or applied on its own.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


def check(root, terraform):
    errors = []
    snippets = 0
    documents = sorted(path for path in root.rglob("*.md")
                       if not any(part.startswith(".") for part in path.relative_to(root).parts))
    for path in documents:
        label = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        fence = None
        body = []
        for number, line in enumerate(lines, 1):
            marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
            if fence:
                if marker and marker[1][0] == fence[0][0] and len(marker[1]) >= len(fence[0]) and not marker[2].strip():
                    if fence[1] in ("hcl", "terraform"):
                        snippets += 1
                        result = subprocess.run(
                            [terraform, "fmt", "-write=false", "-no-color", "-"],
                            input="\n".join(body) + "\n", encoding="utf-8", capture_output=True)
                        if result.returncode:
                            errors.append(f"{label}:{fence[2]}: invalid HCL\n{result.stderr.strip()}")
                    fence = None
                    body = []
                else:
                    body.append(line)
                continue
            if marker:
                fence = (marker[1], marker[2].strip().lower(), number)
                continue
            for match in re.finditer(r"\]\((<[^>]+>|[^\s)]+)(?:\s+\"[^\"]*\")?\)", line):
                target = match[1].strip("<>")
                url = urlsplit(target)
                if url.scheme or url.netloc or not url.path:
                    continue
                destination = (root if url.path.startswith("/") else path.parent) / unquote(url.path.lstrip("/"))
                if not destination.exists():
                    errors.append(f"{label}:{number}: missing local link target: {target}")
        if fence:
            errors.append(f"{label}:{fence[2]}: unclosed code fence")
    if not documents:
        errors.append("No Markdown documents found.")
    if not snippets:
        errors.append("No HCL examples found; refusing an empty syntax check.")
    for error in errors:
        print(error, file=sys.stderr)
    print(f"Checked {len(documents)} Markdown files and {snippets} HCL snippets; {len(errors)} errors.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--terraform", default="terraform")
    args = parser.parse_args()
    try:
        sys.exit(check(args.root.resolve(), args.terraform))
    except (OSError, ValueError) as error:
        sys.exit(f"Study guide check failed: {error}")
