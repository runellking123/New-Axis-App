#!/usr/bin/env python3
"""Add Phase 1 shared component files to the Axis Xcode project.

Adds 4 Swift files in Axis/Shared/Components/ to:
  - PBXFileReference (once each)
  - PBXBuildFile (once per target: iOS Axis + AxisMac)
  - the Components PBXGroup children
  - the iOS and AxisMac PBXSourcesBuildPhase file lists
"""

import re
import hashlib
import time
import random
import os

PBXPROJ_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Axis.xcodeproj", "project.pbxproj"
)

NEW_FILES = [
    "AxisCharts.swift",
    "AxisImageCard.swift",
    "AxisHeroHeader.swift",
    "AxisMotion.swift",
]

COMPONENTS_GROUP = "D10000000000000000000010"
# Sources build phases that should compile shared components.
SOURCES_PHASES = [
    "C10000000000000000000002",   # iOS "Axis" target
    "F76167D6055EA82740DCCEBE",   # "AxisMac" target
]


def generate_uuid(seed, existing):
    for i in range(10000):
        h = hashlib.md5(f"{seed}_{i}_{time.time()}_{random.randint(0, 10**9)}".encode()).hexdigest()[:24].upper()
        if h not in existing:
            existing.add(h)
            return h
    raise RuntimeError("uuid exhaustion")


def main():
    with open(PBXPROJ_PATH) as f:
        content = f.read()

    if NEW_FILES[0] in content:
        print("Files already present in project.pbxproj — nothing to do.")
        return

    existing = set(re.findall(r'\b([0-9A-F]{24})\b', content))
    lines = content.splitlines(keepends=True)

    # Per-file: one fileRef UUID, plus one buildFile UUID per sources phase.
    entries = []
    for fname in NEW_FILES:
        file_ref = generate_uuid(f"ref_{fname}", existing)
        build_files = {phase: generate_uuid(f"bf_{fname}_{phase}", existing) for phase in SOURCES_PHASES}
        entries.append({"fname": fname, "file_ref": file_ref, "build_files": build_files})

    def insert_before(marker, new_lines):
        for i, line in enumerate(lines):
            if marker in line:
                for nl in reversed(new_lines):
                    lines.insert(i, nl)
                return
        raise RuntimeError(f"marker not found: {marker}")

    # 1. PBXBuildFile entries
    bf_lines = []
    for e in entries:
        for phase, bf_uuid in e["build_files"].items():
            bf_lines.append(
                f"\t\t{bf_uuid} /* {e['fname']} in Sources */ = {{isa = PBXBuildFile; "
                f"fileRef = {e['file_ref']} /* {e['fname']} */; }};\n"
            )
    insert_before("/* End PBXBuildFile section */", bf_lines)

    # 2. PBXFileReference entries
    fr_lines = [
        f"\t\t{e['file_ref']} /* {e['fname']} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = sourcecode.swift; path = {e['fname']}; sourceTree = \"<group>\"; }};\n"
        for e in entries
    ]
    insert_before("/* End PBXFileReference section */", fr_lines)

    # 3. Add to Components group children — find the group definition specifically.
    for i, line in enumerate(lines):
        if f"{COMPONENTS_GROUP} /* Components */ = {{" in line:
            j = i
            while "children = (" not in lines[j]:
                j += 1
            j += 1
            while ");" not in lines[j]:
                j += 1
            child_lines = [f"\t\t\t\t{e['file_ref']} /* {e['fname']} */,\n" for e in entries]
            for cl in reversed(child_lines):
                lines.insert(j, cl)
            break
    else:
        raise RuntimeError("Components group definition not found")

    # 4. Add to each Sources build phase file list.
    for phase in SOURCES_PHASES:
        for i, line in enumerate(lines):
            if f"{phase} /* Sources */ = {{" in line:
                j = i
                while "files = (" not in lines[j]:
                    j += 1
                j += 1
                while ");" not in lines[j]:
                    j += 1
                src_lines = [
                    f"\t\t\t\t{e['build_files'][phase]} /* {e['fname']} in Sources */,\n"
                    for e in entries
                ]
                for sl in reversed(src_lines):
                    lines.insert(j, sl)
                break
        else:
            raise RuntimeError(f"Sources phase not found: {phase}")

    with open(PBXPROJ_PATH, "w") as f:
        f.writelines(lines)

    print(f"Added {len(entries)} files to project.pbxproj")
    for e in entries:
        print(f"  {e['fname']}: ref={e['file_ref']}")


if __name__ == "__main__":
    main()
