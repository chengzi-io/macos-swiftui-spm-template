#!/usr/bin/env python3
"""Adds the AppStore target to App/<App>.xcodeproj for the mac-app-store skill, so no one
edits project.pbxproj by hand.

  xcodeproj.py add-app-store-target <product>...
      Adds the AppStore target (the <App> target's buildable folders and
      App/Configs/AppStore.xcconfig) linking these products of the package at the
      repository root, and its shared scheme.

Runs from anywhere inside the project. Fails, changing nothing, when the project is not
shaped the way the template writes it. Python 3.9 (the one macOS ships) is enough.
"""

import json
import re
import subprocess
import sys
import uuid
from pathlib import Path

# main sets them from the one App/<App>.xcodeproj; the app target is <App>.
PROJECT = None
APP_TARGET = None


def die(message):
    sys.exit(f"error: {message}")


def root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if out.returncode != 0:
        die("not inside a git repository")
    return Path(out.stdout.strip())


class Project:
    def __init__(self, path):
        self.path = path
        self.text = path.read_text()

    def new_id(self):
        while True:
            candidate = uuid.uuid4().hex[:24].upper()
            if candidate not in self.text:
                return candidate

    def entry_span(self, object_id):
        """Start and end of an object's entry, one line or a {...} block."""
        match = re.search(rf"^\t\t{object_id}(?: /\* .*? \*/)? = \{{", self.text, re.M)
        if not match:
            die(f"no object {object_id} in {self.path}")
        line_end = self.text.index("\n", match.end())
        if self.text[match.end() : line_end].rstrip().endswith("};"):
            return match.start(), line_end + 1
        close = self.text.index("\n\t\t};\n", match.end())
        return match.start(), close + len("\n\t\t};\n")

    def entry(self, object_id):
        start, end = self.entry_span(object_id)
        return self.text[start:end]

    def isa(self, object_id):
        return re.search(r"isa = (\w+);", self.entry(object_id)).group(1)

    def objects(self, isa):
        return re.findall(rf"^\t\t([0-9A-F]{{24}})(?: /\* .*? \*/)? = \{{\s*isa = {isa};", self.text, re.M)

    def field(self, object_id, name):
        match = re.search(rf"\b{name} = ([^;\n]+);", self.entry(object_id))
        return match.group(1).split(" /*")[0].strip('"') if match else None

    def list_items(self, object_id, name):
        match = re.search(rf"\b{name} = \(\n(.*?)\t*\);", self.entry(object_id), re.S)
        if not match:
            die(f"object {object_id} has no list {name}")
        return re.findall(r"([0-9A-F]{24})", match.group(1))

    def set_list(self, object_id, name, items):
        start, end = self.entry_span(object_id)
        block = self.text[start:end]
        indent = "\t" * 4
        body = "".join(f"{indent}{item} /* {self.comment(item)} */,\n" for item in items)
        new_block, count = re.subn(
            rf"(\b{name} = \(\n).*?(\t*\);)", lambda m: m.group(1) + body + m.group(2), block, count=1, flags=re.S
        )
        if count != 1:
            die(f"object {object_id} has no list {name}")
        self.text = self.text[:start] + new_block + self.text[end:]

    def comment(self, object_id):
        match = re.search(rf"^\t\t{object_id} /\* (.*?) \*/ = \{{", self.text, re.M)
        return match.group(1) if match else ""

    def add(self, section, entry):
        marker = f"/* End {section} section */"
        if marker not in self.text:
            die(f"{self.path} has no {section} section")
        self.text = self.text.replace(marker, entry + marker, 1)

    def remove(self, object_id):
        start, end = self.entry_span(object_id)
        self.text = self.text[:start] + self.text[end:]

    def target(self, name):
        for target_id in self.objects("PBXNativeTarget"):
            if self.field(target_id, "name") == name:
                return target_id
        return None

    def save(self):
        self.path.write_text(self.text)


def package_products(repo):
    out = subprocess.run(
        ["swift", "package", "--package-path", str(repo), "dump-package"],
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        die(f"swift package dump-package failed:\n{out.stderr}")
    return {product["name"] for product in json.loads(out.stdout)["products"]}


def link(project, target_name, products, available):
    missing = [product for product in products if product not in available]
    if missing:
        die(f"Package.swift has no product {', '.join(missing)}; declare it there first")
    target_id = project.target(target_name)
    if not target_id:
        die(f"no target {target_name} in {PROJECT}")
    frameworks = [p for p in project.list_items(target_id, "buildPhases") if project.isa(p) == "PBXFrameworksBuildPhase"]
    if len(frameworks) != 1:
        die(f"target {target_name} needs exactly one Frameworks build phase")
    phase = frameworks[0]

    dependencies = project.list_items(target_id, "packageProductDependencies")
    current = {project.field(dep, "productName"): dep for dep in dependencies}
    build_files = {
        project.field(build_file, "productRef"): build_file
        for build_file in project.list_items(phase, "files")
        if project.field(build_file, "productRef")
    }

    for product, dep in current.items():
        if product not in products:
            dependencies.remove(dep)
            if dep in build_files:
                project.set_list(phase, "files", [f for f in project.list_items(phase, "files") if f != build_files[dep]])
                project.remove(build_files[dep])
            project.remove(dep)
    for product in products:
        if product in current:
            continue
        dep, build_file = project.new_id(), project.new_id()
        project.add(
            "XCSwiftPackageProductDependency",
            f"\t\t{dep} /* {product} */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n"
            f"\t\t\tproductName = {product};\n\t\t}};\n",
        )
        project.add(
            "PBXBuildFile",
            f"\t\t{build_file} /* {product} in Frameworks */ = "
            f"{{isa = PBXBuildFile; productRef = {dep} /* {product} */; }};\n",
        )
        dependencies.append(dep)
        project.set_list(phase, "files", project.list_items(phase, "files") + [build_file])
    project.set_list(target_id, "packageProductDependencies", dependencies)


def add_file_reference(project, group, name, file_type):
    for child in project.list_items(group, "children"):
        if project.field(child, "path") == name:
            return child
    ref = project.new_id()
    project.add(
        "PBXFileReference",
        f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; '
        f'path = {name}; sourceTree = "<group>"; }};\n',
    )
    project.set_list(group, "children", project.list_items(group, "children") + [ref])
    return ref


def add_app_store_target(project, base, products, available):
    if project.target("AppStore"):
        die(f"{PROJECT} already has an AppStore target")
    app = project.target(APP_TARGET)
    if not app:
        die(f"no {APP_TARGET} target in {PROJECT}")
    for name in ("AppStore.xcconfig", "AppStore-Info.plist", "AppStore.entitlements"):
        if not (base / "Configs" / name).is_file():
            die(f"no App/Configs/{name}; create it first (SKILL.md, step 3a.3)")

    configs = next((g for g in project.objects("PBXGroup") if project.field(g, "path") == "Configs"), None)
    if not configs:
        die(f"{PROJECT} has no Configs group")
    xcconfig = add_file_reference(project, configs, "AppStore.xcconfig", "text.xcconfig")
    add_file_reference(project, configs, "AppStore-Info.plist", "text.plist.xml")
    add_file_reference(project, configs, "AppStore.entitlements", "text.plist.entitlements")

    project_id = project.objects("PBXProject")[0]
    products_group = project.field(project_id, "productRefGroup")
    product_ref = project.new_id()
    project.add(
        "PBXFileReference",
        f"\t\t{product_ref} /* AppStore.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; "
        f"includeInIndex = 0; path = AppStore.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n",
    )
    project.set_list(products_group, "children", project.list_items(products_group, "children") + [product_ref])

    phases = {}
    for isa, section, name in (
        ("PBXSourcesBuildPhase", "PBXSourcesBuildPhase", "Sources"),
        ("PBXFrameworksBuildPhase", "PBXFrameworksBuildPhase", "Frameworks"),
        ("PBXResourcesBuildPhase", "PBXResourcesBuildPhase", "Resources"),
    ):
        phase = project.new_id()
        project.add(
            section,
            f"\t\t{phase} /* {name} */ = {{\n\t\t\tisa = {isa};\n\t\t\tbuildActionMask = 2147483647;\n"
            f"\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
        )
        phases[name] = phase

    configurations = []
    for name in ("Debug", "Release"):
        configuration = project.new_id()
        project.add(
            "XCBuildConfiguration",
            f"\t\t{configuration} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbaseConfigurationReference = {xcconfig} /* AppStore.xcconfig */;\n"
            f"\t\t\tbuildSettings = {{\n\t\t\t}};\n\t\t\tname = {name};\n\t\t}};\n",
        )
        configurations.append(configuration)
    configuration_list = project.new_id()
    project.add(
        "XCConfigurationList",
        f'\t\t{configuration_list} /* Build configuration list for PBXNativeTarget "AppStore" */ = {{\n'
        f"\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{configurations[0]} /* Debug */,\n\t\t\t\t{configurations[1]} /* Release */,\n\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n",
    )

    folders = "".join(
        f"\t\t\t\t{group} /* {project.comment(group)} */,\n"
        for group in project.list_items(app, "fileSystemSynchronizedGroups")
    )
    target = project.new_id()
    project.add(
        "PBXNativeTarget",
        f"\t\t{target} /* AppStore */ = {{\n\t\t\tisa = PBXNativeTarget;\n"
        f'\t\t\tbuildConfigurationList = {configuration_list} /* Build configuration list for PBXNativeTarget "AppStore" */;\n'
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{phases['Sources']} /* Sources */,\n"
        f"\t\t\t\t{phases['Frameworks']} /* Frameworks */,\n"
        f"\t\t\t\t{phases['Resources']} /* Resources */,\n\t\t\t);\n"
        f"\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n"
        f"\t\t\tfileSystemSynchronizedGroups = (\n{folders}\t\t\t);\n"
        f"\t\t\tname = AppStore;\n\t\t\tpackageProductDependencies = (\n\t\t\t);\n"
        f"\t\t\tproductName = AppStore;\n\t\t\tproductReference = {product_ref} /* AppStore.app */;\n"
        f'\t\t\tproductType = "com.apple.product-type.application";\n\t\t}};\n',
    )
    project.set_list(project_id, "targets", project.list_items(project_id, "targets") + [target])
    link(project, "AppStore", products, available)

    def reference(indent):
        return (
            f'{indent}<BuildableReference\n{indent}   BuildableIdentifier = "primary"\n'
            f'{indent}   BlueprintIdentifier = "{target}"\n{indent}   BuildableName = "AppStore.app"\n'
            f'{indent}   BlueprintName = "AppStore"\n{indent}   ReferencedContainer = "container:{PROJECT}">\n'
            f"{indent}</BuildableReference>\n"
        )

    scheme = base / PROJECT / "xcshareddata" / "xcschemes" / "AppStore.xcscheme"
    scheme.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<Scheme\n   LastUpgradeVersion = "2620"\n   version = "1.7">\n'
        '   <BuildAction\n      parallelizeBuildables = "YES"\n      buildImplicitDependencies = "YES">\n'
        "      <BuildActionEntries>\n         <BuildActionEntry\n"
        '            buildForTesting = "NO"\n            buildForRunning = "YES"\n            buildForProfiling = "YES"\n'
        '            buildForArchiving = "YES"\n            buildForAnalyzing = "YES">\n'
        + reference(" " * 12)
        + "         </BuildActionEntry>\n      </BuildActionEntries>\n   </BuildAction>\n"
        '   <LaunchAction\n      buildConfiguration = "Debug"\n      launchStyle = "0">\n'
        '      <BuildableProductRunnable\n         runnableDebuggingMode = "0">\n'
        + reference(" " * 9)
        + "      </BuildableProductRunnable>\n   </LaunchAction>\n"
        '   <ArchiveAction\n      buildConfiguration = "Release"\n      revealArchiveInOrganizer = "YES">\n'
        "   </ArchiveAction>\n</Scheme>\n"
    )


def main():
    if len(sys.argv) < 3 or sys.argv[1] != "add-app-store-target":
        die(__doc__.split("\n\n")[1].strip())
    products = sys.argv[2:]
    if len(set(products)) != len(products):
        die("a product is named twice")
    global PROJECT, APP_TARGET
    repo = root()
    base = repo / "App"
    projects = sorted(p.parent.name for p in base.glob("*.xcodeproj/project.pbxproj"))
    if len(projects) != 1:
        die(f"expected one Xcode project in {base}, found: {', '.join(projects) or 'none'}")
    PROJECT = projects[0]
    APP_TARGET = PROJECT[: -len(".xcodeproj")]
    pbxproj = base / PROJECT / "project.pbxproj"
    project = Project(pbxproj)
    add_app_store_target(project, base, products, package_products(repo))
    project.save()


if __name__ == "__main__":
    main()
