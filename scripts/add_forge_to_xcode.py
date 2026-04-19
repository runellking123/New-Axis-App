#!/usr/bin/env python3
"""Add Forge feature files to the Axis Xcode project (project.pbxproj)."""

import re
import hashlib
import time
import random

PBXPROJ_PATH = "/Users/dr.runellking/Developer/axis/Axis.xcodeproj/project.pbxproj"

# Files to add: (relative path from Axis/, filename, parent group key)
FILES_TO_ADD = [
    ("Models/ForgeModels.swift", "ForgeModels.swift", "Models"),
    ("Services/ForgeService.swift", "ForgeService.swift", "Services"),
    ("Features/Forge/ForgeViewModel.swift", "ForgeViewModel.swift", "Forge"),
    ("Features/Forge/ForgeView.swift", "ForgeView.swift", "Forge"),
]

# Existing group UUIDs
MODELS_GROUP = "D1000000000000000000000D"
SERVICES_GROUP = "D1000000000000000000000E"
FEATURES_GROUP = "D10000000000000000000004"
SOURCES_BUILD_PHASE = "C10000000000000000000002"


def generate_uuid(seed, existing_uuids):
    for i in range(1000):
        hash_input = f"{seed}_{i}_{time.time()}_{random.randint(0, 999999)}"
        raw = hashlib.md5(hash_input.encode()).hexdigest()[:24].upper()
        if raw not in existing_uuids:
            existing_uuids.add(raw)
            return raw
    raise RuntimeError(f"Could not generate unique UUID for seed: {seed}")


def collect_existing_uuids(content):
    return set(re.findall(r'\b([0-9A-F]{24})\b', content))


def add_child_to_group(lines, group_uuid, child_uuid, child_name):
    in_group = False
    in_children = False
    for i, line in enumerate(lines):
        if f"{group_uuid} /*" in line and "isa = PBXGroup" not in line:
            in_group = True
            continue
        if in_group and "isa = PBXGroup" in line:
            continue
        if in_group and "children = (" in line:
            in_children = True
            continue
        if in_group and in_children and ");" in line:
            new_child_line = f"\t\t\t\t{child_uuid} /* {child_name} */,\n"
            lines.insert(i, new_child_line)
            return lines
    return lines


def main():
    with open(PBXPROJ_PATH, 'r') as f:
        content = f.read()

    existing_uuids = collect_existing_uuids(content)
    lines = content.splitlines(keepends=True)

    # Generate UUIDs for all files
    file_entries = []
    for rel_path, filename, group_path in FILES_TO_ADD:
        file_ref_uuid = generate_uuid(f"fileref_{filename}", existing_uuids)
        build_file_uuid = generate_uuid(f"buildfile_{filename}", existing_uuids)
        file_entries.append({
            'rel_path': rel_path,
            'filename': filename,
            'group_path': group_path,
            'file_ref_uuid': file_ref_uuid,
            'build_file_uuid': build_file_uuid,
        })

    # Generate UUID for the new Forge group
    forge_group_uuid = generate_uuid("group_Forge", existing_uuids)

    # ===== Step 1: Add PBXBuildFile entries =====
    build_section_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXBuildFile section */' in line:
            build_section_end_idx = i
            break

    for entry in sorted(file_entries, key=lambda x: x['build_file_uuid'], reverse=True):
        bf_line = f"\t\t{entry['build_file_uuid']} /* {entry['filename']} in Sources */ = {{isa = PBXBuildFile; fileRef = {entry['file_ref_uuid']} /* {entry['filename']} */; }};\n"
        lines.insert(build_section_end_idx, bf_line)

    # ===== Step 2: Add PBXFileReference entries =====
    file_ref_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXFileReference section */' in line:
            file_ref_end_idx = i
            break

    for entry in sorted(file_entries, key=lambda x: x['file_ref_uuid'], reverse=True):
        fr_line = f"\t\t{entry['file_ref_uuid']} /* {entry['filename']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {entry['filename']}; sourceTree = \"<group>\"; }};\n"
        lines.insert(file_ref_end_idx, fr_line)

    # ===== Step 3: Create Forge PBXGroup =====
    forge_children = [(e['file_ref_uuid'], e['filename']) for e in file_entries if e['group_path'] == 'Forge']
    forge_children.sort(key=lambda x: x[1])

    children_lines = ""
    for uuid, fname in forge_children:
        children_lines += f"\t\t\t\t{uuid} /* {fname} */,\n"

    forge_group_block = (
        f"\t\t{forge_group_uuid} /* Forge */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"{children_lines}"
        f"\t\t\t);\n"
        f"\t\t\tpath = Forge;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )

    group_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXGroup section */' in line:
            group_end_idx = i
            break
    lines.insert(group_end_idx, forge_group_block)

    # ===== Step 4: Add children to existing groups =====
    # Add ForgeModels.swift to Models group
    for entry in file_entries:
        if entry['group_path'] == 'Models':
            lines = add_child_to_group(lines, MODELS_GROUP, entry['file_ref_uuid'], entry['filename'])
        elif entry['group_path'] == 'Services':
            lines = add_child_to_group(lines, SERVICES_GROUP, entry['file_ref_uuid'], entry['filename'])

    # Add Forge group to Features group
    lines = add_child_to_group(lines, FEATURES_GROUP, forge_group_uuid, 'Forge')

    # ===== Step 5: Add to PBXSourcesBuildPhase =====
    in_sources = False
    in_files = False
    for i, line in enumerate(lines):
        if f'{SOURCES_BUILD_PHASE} /* Sources */' in line:
            in_sources = True
            continue
        if in_sources and 'files = (' in line:
            in_files = True
            continue
        if in_sources and in_files and ');' in line:
            for entry in reversed(file_entries):
                sf_line = f"\t\t\t\t{entry['build_file_uuid']} /* {entry['filename']} in Sources */,\n"
                lines.insert(i, sf_line)
            break

    with open(PBXPROJ_PATH, 'w') as f:
        f.writelines(lines)

    print(f"Successfully added {len(file_entries)} Forge files to project.pbxproj")
    print(f"Forge group UUID: {forge_group_uuid}")
    for entry in file_entries:
        print(f"  {entry['file_ref_uuid']} -> {entry['filename']}")


if __name__ == '__main__':
    main()
