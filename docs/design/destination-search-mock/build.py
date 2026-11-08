#!/usr/bin/env python3
"""Builds docs/design/destination-search-mock/index.html from the parts in this folder and the fictional sample archive.

The mockup shows the three destination-search concepts of docs/design/destination-search-study.md. The sample data
lives in docs/design/sample-data/ (folders.txt from make_sample_archive.py, folder-files.txt written by hand); it is
invented from scratch and describes no real archive. Edit the parts here and rerun `python3 build.py`; edits made
directly to index.html are lost on the next build.
"""
import argparse
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "index.html")


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def load_folders(data_dir):
    with open(os.path.join(data_dir, "folders.txt"), encoding="utf-8") as f:
        paths = [line.rstrip("\n") for line in f if line.strip()]
    return [p for p in paths if p.split("/")[-1] != "Icon"]


def load_contents(data_dir):
    contents = {}
    current = None
    with open(os.path.join(data_dir, "folder-files.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("## "):
                current = line[3:]
                contents[current] = []
            elif line.strip() and current is not None:
                if line == "Icon":
                    continue
                contents[current].append(line)
    # Keep only entries with an extension: subfolders come from the folder list.
    return {k: [n for n in v if re.search(r"\.[A-Za-z0-9]{2,6}$", n)] for k, v in contents.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", default=os.path.join(os.path.dirname(HERE), "sample-data"), help="folder holding folders.txt and folder-files.txt")
    data_dir = parser.parse_args().data
    folders = load_folders(data_dir)
    contents = load_contents(data_dir)
    data_js = (
        "const FOLDERS = " + json.dumps(folders, ensure_ascii=False, separators=(",", ":")) + ";\n"
        "const KNOWN_CONTENTS = " + json.dumps(contents, ensure_ascii=False, separators=(",", ":")) + ";\n"
    )
    html = (
        "<title>Destination Search Concepts</title>\n<meta charset=\"utf-8\">\n"
        '<meta name="claude:viewport-fit-sides" content="cover">\n'
        "<style>\n" + read("style.css") + "</style>\n"
        + read("body.html")
        + "<script>\n" + data_js + "</script>\n"
        + "<script>\n" + read("app.js") + "</script>\n"
    )
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"wrote {OUT}: {len(html.encode('utf-8')):,} bytes, {len(folders)} folders")


if __name__ == "__main__":
    main()
