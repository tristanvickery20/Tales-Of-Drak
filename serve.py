#!/usr/bin/env python3
"""Tales of Drak — framework dashboard.

Lightweight web preview for the Godot framework prototype. Serves the project
documentation and design data files in a browsable form, and surfaces the
output of the framework validator.

Bind: 0.0.0.0:5000 (Replit web preview).
"""

from __future__ import annotations

import html
import json
import subprocess
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent
DESIGN_DIR = ROOT / "design"
DOCS_DIR = ROOT / "docs"
VALIDATOR = ROOT / "tools" / "validate_character_framework.py"

HOST = "0.0.0.0"
PORT = 5000

PAGE_CSS = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #0f1115;
  color: #e6e6e6;
  line-height: 1.55;
}
header {
  padding: 2rem 2rem 1rem;
  border-bottom: 1px solid #222831;
  background: linear-gradient(180deg, #151821 0%, #0f1115 100%);
}
header h1 { margin: 0 0 0.25rem; font-size: 1.6rem; letter-spacing: 0.02em; }
header p  { margin: 0; color: #9aa3b2; }
nav {
  display: flex; gap: 1rem; padding: 0.75rem 2rem;
  background: #11141b; border-bottom: 1px solid #222831;
  position: sticky; top: 0; z-index: 5;
}
nav a { color: #9aa3b2; text-decoration: none; font-size: 0.95rem; }
nav a:hover, nav a.active { color: #f3c969; }
main { padding: 1.5rem 2rem 4rem; max-width: 1100px; }
h2 { color: #f3c969; border-bottom: 1px solid #222831; padding-bottom: 0.4rem; }
ul { padding-left: 1.2rem; }
li { margin: 0.25rem 0; }
a { color: #7fb3ff; }
.status {
  display: inline-block; padding: 0.15rem 0.6rem; border-radius: 999px;
  font-size: 0.8rem; font-weight: 600;
}
.status.ok { background: #14532d; color: #bbf7d0; }
.status.bad { background: #7f1d1d; color: #fecaca; }
pre {
  background: #11141b; border: 1px solid #222831; border-radius: 8px;
  padding: 1rem; overflow-x: auto; font-size: 0.85rem;
}
.cards {
  display: grid; gap: 1rem;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  margin-top: 1rem;
}
.card {
  border: 1px solid #222831; border-radius: 10px; padding: 1rem;
  background: #141821;
}
.card h3 { margin: 0 0 0.4rem; font-size: 1rem; }
.card .meta { color: #9aa3b2; font-size: 0.8rem; }
.muted { color: #9aa3b2; }
table { width: 100%; border-collapse: collapse; margin-top: 0.5rem; }
th, td { text-align: left; padding: 0.4rem 0.6rem; border-bottom: 1px solid #222831; font-size: 0.9rem; }
th { color: #9aa3b2; font-weight: 600; }
"""


def page(title: str, body: str, active: str = "") -> bytes:
    nav_items = [
        ("home", "/", "Overview"),
        ("design", "/design/", "Design Data"),
        ("docs", "/docs/", "Docs"),
        ("validate", "/validate", "Validator"),
    ]
    nav_html = "".join(
        f'<a class="{ "active" if key == active else "" }" href="{href}">{label}</a>'
        for key, href, label in nav_items
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)} — Tales of Drak</title>
  <style>{PAGE_CSS}</style>
</head>
<body>
  <header>
    <h1>Tales of Drak</h1>
    <p>Framework Prototype v0.1 — dark fantasy co-op RPG foundation for Godot.</p>
  </header>
  <nav>{nav_html}</nav>
  <main>{body}</main>
</body>
</html>""".encode("utf-8")


def render_markdown(text: str) -> str:
    """Very small Markdown subset renderer (headings, lists, code, paragraphs)."""
    lines = text.splitlines()
    out: list[str] = []
    in_code = False
    in_list = False
    para: list[str] = []

    def flush_para() -> None:
        if para:
            out.append("<p>" + " ".join(html.escape(p) for p in para) + "</p>")
            para.clear()

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in lines:
        line = raw.rstrip()
        if line.startswith("```"):
            flush_para(); close_list()
            if not in_code:
                out.append("<pre><code>")
                in_code = True
            else:
                out.append("</code></pre>")
                in_code = False
            continue
        if in_code:
            out.append(html.escape(raw))
            continue
        if not line.strip():
            flush_para(); close_list()
            continue
        if line.startswith("### "):
            flush_para(); close_list()
            out.append(f"<h3>{html.escape(line[4:])}</h3>")
        elif line.startswith("## "):
            flush_para(); close_list()
            out.append(f"<h2>{html.escape(line[3:])}</h2>")
        elif line.startswith("# "):
            flush_para(); close_list()
            out.append(f"<h1>{html.escape(line[2:])}</h1>")
        elif line.lstrip().startswith(("- ", "* ")):
            flush_para()
            if not in_list:
                out.append("<ul>")
                in_list = True
            item = line.lstrip()[2:]
            out.append(f"<li>{html.escape(item)}</li>")
        else:
            close_list()
            para.append(line)
    flush_para(); close_list()
    if in_code:
        out.append("</code></pre>")
    return "\n".join(out)


def render_index() -> bytes:
    design_files = sorted(p.name for p in DESIGN_DIR.glob("*.json"))
    doc_files = sorted(p.name for p in DOCS_DIR.glob("*.md"))
    cards = []
    for name in design_files:
        try:
            data = json.loads((DESIGN_DIR / name).read_text())
            count = len(data.get("records", []))
            rtype = data.get("record_type", "?")
        except Exception:
            count, rtype = 0, "?"
        cards.append(
            f'<div class="card"><h3><a href="/design/{name}">{html.escape(name)}</a></h3>'
            f'<div class="meta">type: {html.escape(rtype)} · {count} records</div></div>'
        )
    body = f"""
      <h2>Overview</h2>
      <p class="muted">
        This is a data-driven Godot framework prototype. The repo holds JSON
        design data, Godot scripts/scenes, design docs, and a validator that
        checks the data contract. Use the navigation above to browse.
      </p>

      <h2>Design data ({len(design_files)} files)</h2>
      <div class="cards">{''.join(cards)}</div>

      <h2>Docs ({len(doc_files)} files)</h2>
      <ul>
        {''.join(f'<li><a href="/docs/{html.escape(n)}">{html.escape(n)}</a></li>' for n in doc_files)}
      </ul>

      <h2>Validator</h2>
      <p>Run the framework data validator and view its output:
      <a href="/validate">/validate</a>.</p>
    """
    return page("Overview", body, active="home")


def render_design_index() -> bytes:
    files = sorted(DESIGN_DIR.glob("*.json"))
    rows = []
    for path in files:
        try:
            data = json.loads(path.read_text())
            records = data.get("records", [])
            rtype = data.get("record_type", "?")
            schema = data.get("schema_version", "?")
            count = len(records)
        except Exception as exc:  # noqa: BLE001
            rtype, schema, count = f"error: {exc}", "?", 0
        rows.append(
            f"<tr><td><a href='/design/{path.name}'>{html.escape(path.name)}</a></td>"
            f"<td>{html.escape(str(rtype))}</td>"
            f"<td>{html.escape(str(schema))}</td>"
            f"<td>{count}</td></tr>"
        )
    body = f"""
      <h2>Design data files</h2>
      <p class="muted">All files live under <code>/design</code> and follow the
      v0.1 data contract (see <a href='/docs/data-contract.md'>data-contract.md</a>).</p>
      <table>
        <thead><tr><th>File</th><th>Record type</th><th>Schema</th><th>Records</th></tr></thead>
        <tbody>{''.join(rows)}</tbody>
      </table>
    """
    return page("Design Data", body, active="design")


def render_design_file(name: str) -> bytes | None:
    path = DESIGN_DIR / name
    if not path.is_file() or path.suffix != ".json":
        return None
    try:
        data = json.loads(path.read_text())
        pretty = json.dumps(data, indent=2)
    except Exception as exc:  # noqa: BLE001
        pretty = f"Failed to parse JSON: {exc}\n\n" + path.read_text()
    body = f"""
      <p><a href="/design/">&larr; back to design data</a></p>
      <h2>{html.escape(name)}</h2>
      <pre>{html.escape(pretty)}</pre>
    """
    return page(name, body, active="design")


def render_docs_index() -> bytes:
    files = sorted(DOCS_DIR.glob("*.md"))
    items = "".join(
        f'<li><a href="/docs/{p.name}">{html.escape(p.name)}</a></li>' for p in files
    )
    body = f"""
      <h2>Docs</h2>
      <p class="muted">Design notes and the data contract.</p>
      <ul>{items}</ul>
    """
    return page("Docs", body, active="docs")


def render_doc_file(name: str) -> bytes | None:
    path = DOCS_DIR / name
    if not path.is_file() or path.suffix != ".md":
        return None
    rendered = render_markdown(path.read_text())
    body = f"""
      <p><a href="/docs/">&larr; back to docs</a></p>
      {rendered}
    """
    return page(name, body, active="docs")


def render_validator() -> bytes:
    try:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            capture_output=True, text=True, timeout=30,
        )
        ok = result.returncode == 0
        output = (result.stdout or "") + (result.stderr or "")
    except Exception as exc:  # noqa: BLE001
        ok = False
        output = f"Failed to run validator: {exc}"
    badge = '<span class="status ok">PASS</span>' if ok else '<span class="status bad">FAIL</span>'
    body = f"""
      <h2>Validator {badge}</h2>
      <p class="muted">Runs <code>tools/validate_character_framework.py</code>
      against the JSON design data.</p>
      <pre>{html.escape(output) or '(no output)'}</pre>
    """
    return page("Validator", body, active="validate")


class Handler(BaseHTTPRequestHandler):
    server_version = "TalesOfDrakDashboard/0.1"

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, status: HTTPStatus, body: bytes, content_type: str = "text/html; charset=utf-8") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = unquote(self.path.split("?", 1)[0])
        if path == "/" or path == "/index.html":
            return self._send(HTTPStatus.OK, render_index())
        if path == "/validate":
            return self._send(HTTPStatus.OK, render_validator())
        if path == "/design/" or path == "/design":
            return self._send(HTTPStatus.OK, render_design_index())
        if path.startswith("/design/"):
            name = path[len("/design/"):]
            body = render_design_file(name)
            if body is None:
                return self._send(HTTPStatus.NOT_FOUND, page("Not Found", "<p>Not found.</p>"))
            return self._send(HTTPStatus.OK, body)
        if path == "/docs/" or path == "/docs":
            return self._send(HTTPStatus.OK, render_docs_index())
        if path.startswith("/docs/"):
            name = path[len("/docs/"):]
            body = render_doc_file(name)
            if body is None:
                return self._send(HTTPStatus.NOT_FOUND, page("Not Found", "<p>Not found.</p>"))
            return self._send(HTTPStatus.OK, body)
        self._send(HTTPStatus.NOT_FOUND, page("Not Found", "<p>Not found.</p>"))


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Tales of Drak dashboard listening on http://{HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down")
        server.shutdown()


if __name__ == "__main__":
    main()
