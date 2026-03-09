#!/usr/bin/env python3
"""
Add 20 Swift files to the Axis Xcode project (project.pbxproj).

This script:
1. Reads the existing project.pbxproj
2. Generates unique 24-char hex UUIDs for PBXFileReference and PBXBuildFile entries
3. Adds PBXFileReference entries
4. Adds PBXBuildFile entries
5. Creates PBXGroup entries for new EA subdirectories
6. Adds children to existing groups (Balance, Trends, Models, Services, Features)
7. Adds PBXBuildFile references to PBXSourcesBuildPhase
"""

import re
import hashlib
import time
import random

PBXPROJ_PATH = "/Users/dr.runellking/Axis/Axis.xcodeproj/project.pbxproj"

# Files to add, grouped by their parent group
FILES_TO_ADD = [
    # Balance group (existing: D10000000000000000000005)
    ("Features/Balance/SleepDetailView.swift", "SleepDetailView.swift", "Balance"),
    ("Features/Balance/StepsDetailView.swift", "StepsDetailView.swift", "Balance"),
    # Trends group (existing: 7BB79E5A8AB790A2821FF14B)
    ("Features/Trends/MetricDetailView.swift", "MetricDetailView.swift", "Trends"),
    # EA subgroups (new groups needed)
    ("Features/EA/Capture/EACaptureResultSheet.swift", "EACaptureResultSheet.swift", "EA/Capture"),
    ("Features/EA/Capture/EAQuickCaptureOverlay.swift", "EAQuickCaptureOverlay.swift", "EA/Capture"),
    ("Features/EA/Tasks/EATaskListView.swift", "EATaskListView.swift", "EA/Tasks"),
    ("Features/EA/Tasks/EATaskReducer.swift", "EATaskReducer.swift", "EA/Tasks"),
    ("Features/EA/Planner/EAPlannerReducer.swift", "EAPlannerReducer.swift", "EA/Planner"),
    ("Features/EA/Planner/EAPlannerView.swift", "EAPlannerView.swift", "EA/Planner"),
    ("Features/EA/Projects/EAProjectListView.swift", "EAProjectListView.swift", "EA/Projects"),
    ("Features/EA/Projects/EAProjectReducer.swift", "EAProjectReducer.swift", "EA/Projects"),
    ("Features/EA/Dashboard/EADashboardReducer.swift", "EADashboardReducer.swift", "EA/Dashboard"),
    ("Features/EA/Dashboard/EADashboardView.swift", "EADashboardView.swift", "EA/Dashboard"),
    # Models group (existing: D1000000000000000000000D)
    ("Models/EAProject.swift", "EAProject.swift", "Models"),
    ("Models/EADailyPlan.swift", "EADailyPlan.swift", "Models"),
    ("Models/EAInboxItem.swift", "EAInboxItem.swift", "Models"),
    ("Models/EATimeBlock.swift", "EATimeBlock.swift", "Models"),
    ("Models/EAMilestone.swift", "EAMilestone.swift", "Models"),
    ("Models/EATask.swift", "EATask.swift", "Models"),
    # Services group (existing: D1000000000000000000000E)
    ("Services/AIExecutiveService.swift", "AIExecutiveService.swift", "Services"),
]


def generate_uuid(seed, existing_uuids):
    """Generate a unique 24-character hex UUID that doesn't collide with existing ones."""
    for i in range(1000):
        hash_input = f"{seed}_{i}_{time.time()}_{random.randint(0, 999999)}"
        raw = hashlib.md5(hash_input.encode()).hexdigest()[:24].upper()
        if raw not in existing_uuids:
            existing_uuids.add(raw)
            return raw
    raise RuntimeError(f"Could not generate unique UUID for seed: {seed}")


def collect_existing_uuids(content):
    """Find all 24-char hex UUIDs already in the file."""
    return set(re.findall(r'\b([0-9A-F]{24})\b', content))


def add_child_to_group(lines, group_uuid, child_uuid, child_name):
    """Find the group by UUID and add a child to its children list."""
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
            # Insert before the closing paren
            new_child_line = f"\t\t\t\t{child_uuid} /* {child_name} */,\n"
            lines.insert(i, new_child_line)
            return lines
    return lines


def main():
    with open(PBXPROJ_PATH, 'r') as f:
        content = f.read()

    existing_uuids = collect_existing_uuids(content)
    lines = content.splitlines(keepends=True)

    # If the file doesn't end with newline, ensure it does
    if not content.endswith('\n'):
        lines[-1] = lines[-1] + '\n'

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

    # Generate UUIDs for new groups
    new_groups = {}
    for group_name in ['EA', 'EA/Capture', 'EA/Tasks', 'EA/Planner', 'EA/Projects', 'EA/Dashboard']:
        group_uuid = generate_uuid(f"group_{group_name}", existing_uuids)
        new_groups[group_name] = group_uuid

    # ===== Step 1: Add PBXBuildFile entries =====
    build_file_lines = []
    for entry in file_entries:
        line = f"\t\t{entry['build_file_uuid']} /* {entry['filename']} in Sources */ = {{isa = PBXBuildFile; fileRef = {entry['file_ref_uuid']} /* {entry['filename']} */; }};\n"
        build_file_lines.append((entry['build_file_uuid'], line))

    # Find the end of PBXBuildFile section and insert all new lines
    build_section_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXBuildFile section */' in line:
            build_section_end_idx = i
            break

    # Sort by UUID and insert before the end marker
    build_file_lines.sort(key=lambda x: x[0])
    for uuid_key, bfline in reversed(build_file_lines):
        lines.insert(build_section_end_idx, bfline)

    # ===== Step 2: Add PBXFileReference entries =====
    file_ref_lines = []
    for entry in file_entries:
        line = f"\t\t{entry['file_ref_uuid']} /* {entry['filename']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {entry['filename']}; sourceTree = \"<group>\"; }};\n"
        file_ref_lines.append((entry['file_ref_uuid'], line))

    # Find the end of PBXFileReference section
    file_ref_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXFileReference section */' in line:
            file_ref_end_idx = i
            break

    file_ref_lines.sort(key=lambda x: x[0])
    for uuid_key, frline in reversed(file_ref_lines):
        lines.insert(file_ref_end_idx, frline)

    # ===== Step 3: Create new PBXGroup entries and modify existing ones =====

    # Build children lists for new EA subgroups
    ea_subgroup_children = {
        'EA/Capture': [],
        'EA/Tasks': [],
        'EA/Planner': [],
        'EA/Projects': [],
        'EA/Dashboard': [],
    }
    for entry in file_entries:
        if entry['group_path'] in ea_subgroup_children:
            ea_subgroup_children[entry['group_path']].append(
                (entry['file_ref_uuid'], entry['filename'])
            )

    # Sort children alphabetically by filename
    for key in ea_subgroup_children:
        ea_subgroup_children[key].sort(key=lambda x: x[1])

    ea_subgroup_names = ['Capture', 'Dashboard', 'Planner', 'Projects', 'Tasks']  # alphabetical

    # Generate new group text blocks
    new_group_blocks = []

    # EA parent group
    ea_children_lines = ""
    for sub in ea_subgroup_names:
        full_name = f"EA/{sub}"
        ea_children_lines += f"\t\t\t\t{new_groups[full_name]} /* {sub} */,\n"
    ea_group_block = (
        f"\t\t{new_groups['EA']} /* EA */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"{ea_children_lines}"
        f"\t\t\t);\n"
        f"\t\t\tpath = EA;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    new_group_blocks.append(ea_group_block)

    # EA subgroups
    for sub in ea_subgroup_names:
        full_name = f"EA/{sub}"
        children_lines = ""
        for uuid, fname in ea_subgroup_children[full_name]:
            children_lines += f"\t\t\t\t{uuid} /* {fname} */,\n"
        group_block = (
            f"\t\t{new_groups[full_name]} /* {sub} */ = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n"
            f"{children_lines}"
            f"\t\t\t);\n"
            f"\t\t\tpath = {sub};\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};\n"
        )
        new_group_blocks.append(group_block)

    # Insert new groups before "/* End PBXGroup section */"
    group_end_idx = None
    for i, line in enumerate(lines):
        if '/* End PBXGroup section */' in line:
            group_end_idx = i
            break

    for block in reversed(new_group_blocks):
        lines.insert(group_end_idx, block)

    # Now add file references to EXISTING groups

    # Add SleepDetailView.swift and StepsDetailView.swift to Balance group (D10000000000000000000005)
    balance_files = [(e['file_ref_uuid'], e['filename']) for e in file_entries if e['group_path'] == 'Balance']
    for uuid, fname in sorted(balance_files, key=lambda x: x[1], reverse=True):
        lines = add_child_to_group(lines, 'D10000000000000000000005', uuid, fname)

    # Add MetricDetailView.swift to Trends group (7BB79E5A8AB790A2821FF14B)
    trends_files = [(e['file_ref_uuid'], e['filename']) for e in file_entries if e['group_path'] == 'Trends']
    for uuid, fname in trends_files:
        lines = add_child_to_group(lines, '7BB79E5A8AB790A2821FF14B', uuid, fname)

    # Add model files to Models group (D1000000000000000000000D)
    model_files = [(e['file_ref_uuid'], e['filename']) for e in file_entries if e['group_path'] == 'Models']
    for uuid, fname in sorted(model_files, key=lambda x: x[1], reverse=True):
        lines = add_child_to_group(lines, 'D1000000000000000000000D', uuid, fname)

    # Add AIExecutiveService.swift to Services group (D1000000000000000000000E)
    service_files = [(e['file_ref_uuid'], e['filename']) for e in file_entries if e['group_path'] == 'Services']
    for uuid, fname in service_files:
        lines = add_child_to_group(lines, 'D1000000000000000000000E', uuid, fname)

    # Add EA group to Features group (D10000000000000000000004)
    lines = add_child_to_group(lines, 'D10000000000000000000004', new_groups['EA'], 'EA')

    # ===== Step 4: Add PBXBuildFile references to PBXSourcesBuildPhase =====
    sources_files_to_add = []
    for entry in file_entries:
        sources_files_to_add.append(
            f"\t\t\t\t{entry['build_file_uuid']} /* {entry['filename']} in Sources */,\n"
        )

    # Find the closing ); of the files list inside PBXSourcesBuildPhase
    in_sources = False
    in_files = False
    for i, line in enumerate(lines):
        if 'C10000000000000000000002 /* Sources */' in line:
            in_sources = True
            continue
        if in_sources and 'files = (' in line:
            in_files = True
            continue
        if in_sources and in_files and ');' in line:
            # Insert all build file refs before this line
            for sf_line in reversed(sources_files_to_add):
                lines.insert(i, sf_line)
            break

    # Write the modified file
    with open(PBXPROJ_PATH, 'w') as f:
        f.writelines(lines)

    print(f"Successfully added {len(file_entries)} files to project.pbxproj")
    print(f"Created {len(new_groups)} new groups: {', '.join(new_groups.keys())}")
    print("\nFile reference UUIDs:")
    for entry in file_entries:
        print(f"  {entry['file_ref_uuid']} -> {entry['filename']}")
    print("\nBuild file UUIDs:")
    for entry in file_entries:
        print(f"  {entry['build_file_uuid']} -> {entry['filename']}")
    print("\nGroup UUIDs:")
    for name, uuid in new_groups.items():
        print(f"  {uuid} -> {name}")


if __name__ == '__main__':
    main()
