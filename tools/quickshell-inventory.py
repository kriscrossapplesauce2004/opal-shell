#!/usr/bin/env python3
"""Inventory Quickshell use in opal/src QML files (stdlib only).

Type catalog comes from the Quickshell qmltypes files (--qml-dir).
Output: text tables, or JSON with --json.
"""
import argparse
import glob
import json
import os
import re
import sys
from collections import defaultdict
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_SRC = os.path.join(ROOT, "opal", "src")
DEFAULT_QML_DIR = "/usr/lib/qt6/qml/Quickshell"

# Group per type. Anything not listed falls into "other".
GROUPS = {
    "windows/surfaces": {
        "PanelWindow", "FloatingWindow", "PopupWindow", "ReloadPopup", "WlrLayershell",
        "WlSessionLock", "WlSessionLockSurface", "ShellScreen", "WlrKeyboardFocus",
        "WlrLayer", "ExclusionMode", "Region", "Intersection",
    },
    "compositor (Hyprland)": {
        "Hyprland", "HyprlandWindow", "HyprlandWorkspace", "HyprlandMonitor",
        "HyprlandFocusGrab", "HyprlandGlobalShortcut",
    },
    "compositor (Wayland)": {
        "ToplevelManager", "ScreencopyView", "Toplevel", "ToplevelHandle", "IdleInhibitor",
    },
    "services": {
        "Pipewire", "PwNode", "PwNodeAudio", "PwObjectTracker", "PwNodeLinkTracker", "PwLink",
        "UPower", "UPowerDevice", "Mpris", "MprisPlayer", "NotificationServer", "Notification",
        "NotificationAction", "SystemTray", "SystemTrayItem", "Polkit", "PolkitAgent",
        "PolkitFlow", "Pam", "PamContext", "PamResult", "Greetd", "GreetdState",
    },
    "I/O": {
        "Process", "FileView", "FileViewAdapter", "FileViewInternal", "Socket", "SocketServer",
        "DataStream", "JsonAdapter", "StdioCollector", "SplitParser", "DirectoryModel",
    },
    "IPC": {"IpcHandler"},
    "core runtime": {
        "Quickshell", "QuickshellGlobal", "ShellRoot", "Scope", "Variants", "LazyLoader", "Singleton",
        "SystemClock", "DesktopEntries",
        "Reloadable", "Retainable", "QuickshellSettings", "IconImage", "ClippingRectangle",
        "ClippingWrapperRectangle", "WrapperItem", "WrapperMouseArea", "WrapperRectangle",
    },
}
# Quickshell modules whose catalog entries are relevant here.
SHELL_MODULE_PREFIX = "Quickshell"


def group_of(name, module):
    for g, names in GROUPS.items():
        if name in names:
            return g
    if name == "IpcHandler":
        return "IPC"
    if module.startswith("Quickshell.Services"):
        return "services"
    if module == "Quickshell.Io":
        return "I/O"
    if module == "Quickshell.Hyprland":
        return "compositor (Hyprland)"
    if module == "Quickshell.Wayland":
        return "compositor (Wayland)"
    if module == "Quickshell":
        return "core runtime"
    return "other"


def strip_code(text):
    """Blank out comments and string literals, keeping line numbers."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        two = text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join("\n" if ch == "\n" else " " for ch in text[i:j]))
            i = j
        elif c in "\"'`":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            out.append(c + " " * (j - i - 2) + c if j - i >= 2 else " " * (j - i))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def public_module(qml_module):
    """Quickshell.Wayland._WlrLayerShell -> Quickshell.Wayland; Quickshell._Window -> Quickshell."""
    parts = [p for p in qml_module.split(".") if not p.startswith("_")]
    return ".".join(parts)


def parse_block_fields(block_lines, indent):
    """Return the name: values of entries opened at the given indent."""
    names = []
    pat_open = re.compile(r"^ {%d}(Property|Method|Signal|Enum)\s*\{" % indent)
    i = 0
    while i < len(block_lines):
        m = pat_open.match(block_lines[i])
        if m and "}" in block_lines[i]:
            nm = re.search(r"name:\s*\"([^\"]+)\"", block_lines[i])
            if nm:
                names.append((m.group(1), nm.group(1)))
            i += 1
            continue
        if m:
            depth = 0
            j = i
            entry_name = None
            while j < len(block_lines):
                line = block_lines[j]
                if j > i and entry_name is None:
                    nm = re.match(r"^ {%d}name:\s*\"([^\"]+)\"" % (indent + 4), line)
                    if nm:
                        entry_name = nm.group(1)
                depth += line.count("{") - line.count("}")
                if depth <= 0 and j > i:
                    break
                j += 1
            if entry_name:
                names.append((m.group(1), entry_name))
            i = j + 1
        else:
            i += 1
    return names


def load_catalog(qml_dir):
    """Map QML type name -> info dict, from every qmltypes file under qml_dir."""
    catalog = {}
    files = sorted(glob.glob(os.path.join(qml_dir, "**", "*.qmltypes"), recursive=True))
    for path in files:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        i = 0
        while i < len(lines):
            if re.match(r"^    Component \{", lines[i]):
                j = i
                depth = 0
                while j < len(lines):
                    depth += lines[j].count("{") - lines[j].count("}")
                    if depth <= 0 and j > i:
                        break
                    j += 1
                block = lines[i:j + 1]
                info = parse_component(block)
                if info and info["exports"]:
                    for qname, qmod in info["exports"]:
                        if not qmod.startswith(SHELL_MODULE_PREFIX):
                            continue
                        entry = catalog.setdefault(qname, {
                            "module": public_module(qmod),
                            "qml_module": qmod,
                            "kind": "component",
                            "members": set(),
                            "source": os.path.relpath(path, qml_dir),
                        })
                        if info["singleton"]:
                            entry["kind"] = "singleton"
                        if info["attached"]:
                            entry["kind"] = "attached"
                        if info["enum"]:
                            entry["kind"] = "enum"
                        entry["members"].update(info["members"])
                i = j + 1
            else:
                i += 1
    add_qmldir_types(qml_dir, catalog)
    return catalog


def add_qmldir_types(qml_dir, catalog):
    """Add types that qmldir maps to .qml files (e.g. Quickshell.Io FileView)."""
    for path in sorted(glob.glob(os.path.join(qml_dir, "**", "qmldir"), recursive=True)):
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        mod = re.search(r"^module\s+(\S+)", text, re.M)
        if not mod or not mod.group(1).startswith(SHELL_MODULE_PREFIX):
            continue
        for sing, name, _ver, _file in re.findall(
                r"^(singleton\s+)?(\w+)\s+([\d.]+)\s+(\S+\.qml)", text, re.M):
            if name in catalog:
                continue
            catalog[name] = {
                "module": public_module(mod.group(1)),
                "qml_module": mod.group(1),
                "kind": "singleton" if sing else "component",
                "members": set(),
                "source": os.path.relpath(path, qml_dir),
            }


def parse_component(block):
    text = "\n".join(block)
    exports = []
    m = re.search(r"exports:\s*\[(.*?)\]", text, re.S)
    if m:
        for item in re.findall(r"\"([^\"]+)\"", m.group(1)):
            # "Module.Name/Type 0.0" -> (Type, Module.Name)
            if "/" in item:
                mod, rest = item.split("/", 1)
                exports.append((rest.split(" ")[0], mod))
    body = block[1:-1]
    members = set()
    for vals in re.findall(r"values:\s*\[(.*?)\]", text, re.S):
        members.update(re.findall(r"\"(\w+)\"", vals))
    for kind, name in parse_block_fields(body, 8):
        if kind in ("Property", "Method", "Signal"):
            members.add(name)
    return {
        "exports": exports,
        "singleton": bool(re.search(r"isSingleton:\s*true", text)),
        "attached": bool(re.search(r"attachedType:", text)),
        "enum": bool(re.search(r"^ {8}Enum\s*\{", text, re.M))
        and not re.search(r"^ {8}(Property|Method)\s*\{", text, re.M),
        "members": members,
    }


def scan_file(path, catalog, local_names):
    with open(path, encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    code = strip_code(raw)
    imports = re.findall(r"^\s*import\s+(Quickshell[\w.]*)", code, re.M)
    imported_public = {public_module(m) for m in imports}
    hits = []  # (line, name, role, member)
    lines_index = [0]
    for m in re.finditer(r"\n", code):
        lines_index.append(m.end())

    def line_of(pos):
        lo, hi = 0, len(lines_index) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if lines_index[mid] <= pos:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\b(\s*\.\s*(\w+))?", code):
        name = m.group(1)
        if name not in catalog or name in local_names or not name[0].isupper():
            continue
        info = catalog[name]
        if info["module"] not in imported_public and not imported_public:
            continue
        if info["module"] not in imported_public and info["module"] != "Quickshell":
            continue
        after = code[m.end(1):m.end(1) + 3]
        if re.search(r"(import|pragma)\s+$", code[max(0, m.start() - 12):m.start()]):
            continue  # import or pragma line, not a type use
        if m.group(3) and name == "Quickshell" and m.group(3)[0].isupper():
            continue  # module namespace, e.g. Quickshell.Wayland
        if m.group(3):
            role = "member"
            member = m.group(3)
        elif re.match(r"\s*\{", code[m.end(1):]):
            role = "instantiated"
            member = None
        elif re.search(r"property\s+\w+\s+$", code[max(0, m.start() - 40):m.start()]):
            role = "type-ref"
            member = None
        elif re.match(r"\s*:", code[m.end(1):]) and not re.search(r"[\w)]\s*$", code[max(0, m.start() - 1):m.start()]):
            role = "bare-key"
            member = None
        else:
            role = "reference"
            member = None
        hits.append((line_of(m.start()), name, role, member))
    return imports, hits


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", default=DEFAULT_SRC, help="QML source folder (top level *.qml)")
    ap.add_argument("--qml-dir", default=DEFAULT_QML_DIR, help="Quickshell qmltypes folder")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()

    if not os.path.isdir(args.qml_dir):
        sys.exit("qml dir not found: %s" % args.qml_dir)
    catalog = load_catalog(args.qml_dir)
    files = sorted(glob.glob(os.path.join(args.src, "*.qml")))
    local_names = {os.path.splitext(os.path.basename(f))[0] for f in files}

    import_counts = defaultdict(int)
    import_files = defaultdict(list)
    types = defaultdict(lambda: {"count": 0, "roles": defaultdict(int), "members": defaultdict(int),
                                 "files": defaultdict(int), "module": "", "kind": "", "group": ""})
    file_totals = {}
    quickshell_files = []

    for path in files:
        name = os.path.basename(path)
        imports, hits = scan_file(path, catalog, local_names)
        qs_imports = [m for m in imports]
        for m in qs_imports:
            import_counts[m] += 1
            import_files[m].append(name)
        if qs_imports:
            quickshell_files.append(name)
        for line, tname, role, member in hits:
            t = types[tname]
            t["count"] += 1
            t["roles"][role] += 1
            t["files"][name] += 1
            t["module"] = catalog[tname]["module"]
            t["kind"] = catalog[tname]["kind"]
            t["group"] = group_of(tname, catalog[tname]["module"])
            if member:
                t["members"][member] += 1
        if hits:
            file_totals[name] = len(hits)

    # Unknown members: singleton/attached member names not in the catalog.
    unknown_members = defaultdict(list)
    for tname, t in types.items():
        known = catalog[tname]["members"]
        for mem in t["members"]:
            if known and mem not in known:
                unknown_members[tname].append(mem)

    result = {
        "imports": {k: {"files": sorted(v), "count": import_counts[k]}
                    for k, v in sorted(import_files.items())},
        "quickshell_files": sorted(quickshell_files),
        "types": {k: {
            "module": v["module"], "kind": v["kind"], "group": v["group"], "count": v["count"],
            "roles": dict(sorted(v["roles"].items())),
            "members": dict(sorted(v["members"].items(), key=lambda x: -x[1])),
            "files": dict(sorted(v["files"].items(), key=lambda x: -x[1])),
        } for k, v in sorted(types.items(), key=lambda x: -x[1]["count"])},
        "file_totals": dict(sorted(file_totals.items(), key=lambda x: -x[1])),
        "unknown_members": {k: sorted(set(v)) for k, v in unknown_members.items()},
        "snapshot_date": date.today().isoformat(),
        "totals": {
            "qml_files": len(files),
            "files_importing_quickshell": len(quickshell_files),
            "imports": sum(import_counts.values()),
            "distinct_types": len(types),
            "type_occurrences": sum(t["count"] for t in types.values()),
            "files_with_quickshell_types": len(file_totals),
        },
    }

    if args.json:
        json.dump(result, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    tot = result["totals"]
    print("Snapshot: %s (src: %s)" % (result["snapshot_date"], args.src))
    print("QML files: %(qml_files)d | importing Quickshell: %(files_importing_quickshell)d | "
          "import lines: %(imports)d" % tot)
    print("Distinct Quickshell types: %(distinct_types)d | occurrences: %(type_occurrences)d | "
          "files using them: %(files_with_quickshell_types)d" % tot)
    print("\nImports (count, module):")
    for k, v in result["imports"].items():
        print("  %4d  %s" % (v["count"], k))
    for grp in list(GROUPS) + ["other"]:
        rows = [(k, v) for k, v in result["types"].items() if v["group"] == grp]
        if not rows:
            continue
        print("\n== %s (%d occurrences) ==" % (grp, sum(v["count"] for _, v in rows)))
        for k, v in rows:
            roles = ", ".join("%s %d" % (r, c) for r, c in v["roles"].items())
            print("  %4d  %s [%s, %s] (%s)" % (v["count"], k, v["module"], v["kind"], roles))
            if v["members"]:
                mems = ", ".join("%s %d" % (m, c) for m, c in v["members"].items())
                print("        members: %s" % mems)
            print("        files: %s" % ", ".join("%s(%d)" % (f, c) for f, c in v["files"].items()))
    if result["unknown_members"]:
        print("\nMembers not in the qmltypes catalog (check spelling or version):")
        for k, v in result["unknown_members"].items():
            print("  %s: %s" % (k, ", ".join(v)))


if __name__ == "__main__":
    main()
