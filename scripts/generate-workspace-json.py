#!/usr/bin/env python3
"""
IntelliJ IDEA の .idea/ ディレクトリから workspace.json を生成するスクリプト

使い方:
  cd /path/to/project
  python generate-workspace-json.py

これにより kotlin-lsp は GradleWorkspaceImporter ではなく
JsonWorkspaceImporter を使用するようになり、testFixtures ソースセットが
正しく認識されます。
"""

import os
import sys
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional, Any


def parse_iml_file(iml_path: Path, project_dir: Path) -> Optional[Dict[str, Any]]:
    """Parse a single .iml file and extract module information."""
    try:
        tree = ET.parse(iml_path)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Warning: Failed to parse {iml_path}: {e}", file=sys.stderr)
        return None

    module_name = iml_path.stem

    # Extract dependencies
    dependencies = []
    content_roots = []

    for component in root.findall(".//component[@name='NewModuleRootManager']"):
        # Source folders and content roots
        for content in component.findall("content"):
            url = content.get("url", "")
            if url.startswith("file://"):
                # Resolve path
                path = url.replace("file://", "").replace("$MODULE_DIR$", str(iml_path.parent))
                path = path.replace("$PROJECT_DIR$", str(project_dir))
                rel_path = os.path.relpath(path, project_dir)

                source_roots = []
                for source_folder in content.findall("sourceFolder"):
                    src_url = source_folder.get("url", "")
                    is_test = source_folder.get("isTestSource", "false") == "true"

                    src_path = src_url.replace("file://", "").replace("$MODULE_DIR$", str(iml_path.parent))
                    src_path = src_path.replace("$PROJECT_DIR$", str(project_dir))
                    src_rel_path = os.path.relpath(src_path, project_dir)

                    root_type = "java-test" if is_test else "java-source"
                    source_roots.append({
                        "path": f"<WORKSPACE>/{src_rel_path}",
                        "type": root_type
                    })

                if source_roots:
                    content_roots.append({
                        "path": f"<WORKSPACE>/{rel_path}",
                        "sourceRoots": source_roots
                    })

        # Order entries (dependencies)
        for order_entry in component.findall("orderEntry"):
            entry_type = order_entry.get("type")
            scope = order_entry.get("scope", "COMPILE").lower()

            if entry_type == "module":
                dep_module = order_entry.get("module-name")
                if dep_module:
                    dependencies.append({
                        "type": "module",
                        "name": dep_module,
                        "scope": scope
                    })
            elif entry_type == "library":
                lib_name = order_entry.get("name")
                if lib_name:
                    dependencies.append({
                        "type": "library",
                        "name": lib_name,
                        "scope": scope
                    })
            elif entry_type == "inheritedJdk":
                dependencies.append({"type": "inheritedSdk"})
            elif entry_type == "sourceFolder":
                dependencies.append({"type": "moduleSource"})

    return {
        "name": module_name,
        "dependencies": dependencies,
        "contentRoots": content_roots
    }


def resolve_library_path(url: str, gradle_cache: Path, m2_repo: Path) -> Optional[str]:
    """Resolve library path from URL to kotlin-lsp compatible format."""
    if not url.startswith("jar://"):
        return None

    # Extract jar path (remove jar:// prefix and !/ suffix)
    jar_path = url.replace("jar://", "").split("!")[0]

    # Replace IntelliJ placeholders
    jar_path = jar_path.replace("$MAVEN_REPOSITORY$", str(m2_repo))
    jar_path = jar_path.replace("$USER_HOME$", str(Path.home()))

    # Resolve Gradle cache path
    # Format: ~/.gradle/caches/modules-2/files-2.1/group/artifact/version/hash/file.jar
    if ".gradle/caches/modules-2/files-2.1/" in jar_path:
        # Extract relative path from Gradle cache
        parts = jar_path.split(".gradle/caches/modules-2/files-2.1/")
        if len(parts) == 2:
            rel_path = parts[1]  # group/artifact/version/hash/file.jar
            path_parts = rel_path.split("/")
            if len(path_parts) >= 5:
                group = path_parts[0]
                artifact = path_parts[1]
                version = path_parts[2]
                jar_file = path_parts[-1]

                # Convert to Maven repo format
                # <MAVEN_REPO>/group/artifact/version/artifact-version.jar
                group_path = group.replace(".", "/")
                maven_path = f"{group_path}/{artifact}/{version}/{jar_file}"

                # Check if file exists in Maven repo
                m2_jar = m2_repo / maven_path
                if m2_jar.exists():
                    return f"<MAVEN_REPO>/{maven_path}"

                # If not in Maven repo, return full Gradle path
                return jar_path

    # Check if it's already a Maven repo path
    m2_str = str(m2_repo)
    if jar_path.startswith(m2_str):
        rel_path = jar_path[len(m2_str):].lstrip("/")
        return f"<MAVEN_REPO>/{rel_path}"

    # Return absolute path for other cases
    return jar_path


def parse_library_xml(xml_path: Path, gradle_cache: Path) -> Optional[Dict[str, Any]]:
    """Parse a library XML file."""
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Warning: Failed to parse {xml_path}: {e}", file=sys.stderr)
        return None

    library = root.find(".//library")
    if library is None:
        return None

    lib_name = library.get("name")
    if not lib_name:
        return None

    m2_repo = Path.home() / ".m2" / "repository"
    roots = []

    for classes in library.findall(".//CLASSES/root"):
        url = classes.get("url", "")
        resolved_path = resolve_library_path(url, gradle_cache, m2_repo)
        if resolved_path:
            roots.append({"path": resolved_path, "type": "CLASSES"})

    for sources in library.findall(".//SOURCES/root"):
        url = sources.get("url", "")
        resolved_path = resolve_library_path(url, gradle_cache, m2_repo)
        if resolved_path:
            roots.append({"path": resolved_path, "type": "SOURCES"})

    if not roots:
        return None

    return {
        "name": lib_name,
        "type": "java-imported",
        "roots": roots
    }


def generate_kotlin_settings(modules: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Generate Kotlin settings with additionalVisibleModuleNames for test modules."""
    kotlin_settings = []
    module_names = {m["name"] for m in modules}

    for module in modules:
        module_name = module["name"]

        # Determine additional visible modules
        additional_visible = set()

        # For test modules, add corresponding main module
        if module_name.endswith(".test"):
            main_module = module_name.rsplit(".test", 1)[0] + ".main"
            if main_module in module_names:
                additional_visible.add(main_module)
            # Also add testFixtures if exists
            test_fixtures_module = module_name.rsplit(".test", 1)[0] + ".testFixtures"
            if test_fixtures_module in module_names:
                additional_visible.add(test_fixtures_module)

        # For testFixtures modules, add corresponding main module
        elif module_name.endswith(".testFixtures"):
            main_module = module_name.rsplit(".testFixtures", 1)[0] + ".main"
            if main_module in module_names:
                additional_visible.add(main_module)

        # For commandTest modules
        elif module_name.endswith(".commandTest"):
            base = module_name.rsplit(".commandTest", 1)[0]
            for suffix in [".main", ".command", ".testFixtures"]:
                candidate = base + suffix
                if candidate in module_names:
                    additional_visible.add(candidate)

        # Check dependencies for module references and add their main modules
        for dep in module.get("dependencies", []):
            if dep.get("type") == "module":
                dep_name = dep.get("name", "")
                # If depending on a testFixtures, also make its main visible
                if dep_name.endswith(".testFixtures"):
                    main_of_fixture = dep_name.rsplit(".testFixtures", 1)[0] + ".main"
                    if main_of_fixture in module_names:
                        additional_visible.add(main_of_fixture)

        kotlin_settings.append({
            "name": "Kotlin",
            "module": module_name,
            "sourceRoots": [],
            "configFileItems": [],
            "useProjectSettings": True,
            "implementedModuleNames": [],
            "dependsOnModuleNames": [],
            "additionalVisibleModuleNames": list(additional_visible),
            "productionOutputPath": None,
            "testOutputPath": None,
            "sourceSetNames": [],
            "isTestModule": module_name.endswith((".test", ".testFixtures", ".commandTest")),
            "externalProjectId": "",
            "isHmppEnabled": True,
            "pureKotlinSourceFolders": [],
            "kind": "default",
            "compilerArguments": None,
            "additionalArguments": None,
            "scriptTemplates": None,
            "scriptTemplatesClasspath": None,
            "outputDirectoryForJsLibraryFiles": None,
            "targetPlatform": None,
            "externalSystemRunTasks": [],
            "version": 5,
            "flushNeeded": False
        })

    return kotlin_settings


def generate_workspace_json(project_dir: Path) -> Dict[str, Any]:
    """Generate workspace.json from .idea/ directory."""
    idea_dir = project_dir / ".idea"
    modules_dir = idea_dir / "modules"
    libraries_dir = idea_dir / "libraries"

    if not idea_dir.exists():
        raise FileNotFoundError(f".idea/ directory not found in {project_dir}")

    gradle_cache = Path.home() / ".gradle" / "caches" / "modules-2" / "files-2.1"

    # Parse all .iml files
    modules = []
    iml_files = list(modules_dir.rglob("*.iml")) if modules_dir.exists() else []

    # Also check for .iml files in .idea/ root
    iml_files.extend(idea_dir.glob("*.iml"))

    for iml_path in iml_files:
        module = parse_iml_file(iml_path, project_dir)
        if module and module.get("contentRoots"):
            modules.append(module)

    # Parse library files
    libraries = []
    if libraries_dir.exists():
        for lib_xml in libraries_dir.glob("*.xml"):
            library = parse_library_xml(lib_xml, gradle_cache)
            if library:
                libraries.append(library)

    # Generate Kotlin settings for internal visibility
    kotlin_settings = generate_kotlin_settings(modules)

    return {
        "modules": modules,
        "libraries": libraries,
        "kotlinSettings": kotlin_settings
    }


def main():
    project_dir = Path.cwd()

    if len(sys.argv) > 1:
        project_dir = Path(sys.argv[1])

    if not project_dir.exists():
        print(f"Error: Directory not found: {project_dir}", file=sys.stderr)
        sys.exit(1)

    try:
        workspace = generate_workspace_json(project_dir)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    output_path = project_dir / "workspace.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(workspace, f, indent=2, ensure_ascii=False)

    print(f"Generated: {output_path}")
    print(f"  - Modules: {len(workspace['modules'])}")
    print(f"  - Libraries: {len(workspace['libraries'])}")


if __name__ == "__main__":
    main()
