#!/usr/bin/env python3
"""Links package products to a target of App/<App>.xcodeproj, so no one edits project.pbxproj by hand.

  scripts/xcodeproj.py link <target> <product>...
      Makes <target> link exactly these products of the package at the repository root.

Runs from anywhere inside the project. Fails, changing nothing, when the project is not
shaped the way the template writes it. Python 3.9 (the one macOS ships) is enough.
"""

import json
import re
import subprocess
import sys
import uuid
from pathlib import Path

# main sets it from the one App/<App>.xcodeproj.
PROJECT = None


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


def main():
    if len(sys.argv) < 3 or sys.argv[1] != "link":
        die(__doc__.split("\n\n")[1].strip())
    global PROJECT
    repo = root()
    base = repo / "App"
    projects = sorted(p.parent.name for p in base.glob("*.xcodeproj/project.pbxproj"))
    if len(projects) != 1:
        die(f"expected one Xcode project in {base}, found: {', '.join(projects) or 'none'}")
    PROJECT = projects[0]
    project = Project(base / PROJECT / "project.pbxproj")
    link(project, sys.argv[2], sys.argv[3:], package_products(repo))
    project.save()


if __name__ == "__main__":
    main()
