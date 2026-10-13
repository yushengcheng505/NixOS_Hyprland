#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


SCHEMA_VERSION = 1
QUERY_TIMEOUT = 20
NIX = ["nix", "--extra-experimental-features", "nix-command flakes"]
STORE_PATH = re.compile(r"/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+\Z")
OUTPUT_NAMES = {"out", "bin", "dev", "lib", "doc", "man", "info", "debug", "static", "devdoc"}


class BackendError(Exception):
    def __init__(self, code, message):
        self.code = code
        self.message = message
        super().__init__(message)


def diagnostic(code, message):
    return {"code": code, "message": message}


def valid_store_path(value):
    return isinstance(value, str) and bool(STORE_PATH.fullmatch(value)) and not value.endswith(".drv")


def query_json(argv, source):
    try:
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=QUERY_TIMEOUT,
            check=False, stdin=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        raise BackendError(source + "_timeout", source + " query timed out.") from None
    except (OSError, UnicodeError):
        raise BackendError(source + "_unavailable", source + " query could not be started or read.") from None
    if result.returncode != 0:
        raise BackendError(source + "_query_failed", source + " query failed (exit " + str(result.returncode) + ").")
    try:
        return json.loads(result.stdout)
    except (ValueError, RecursionError):
        raise BackendError(source + "_malformed_json", source + " query returned malformed JSON.") from None


def text_field(data, key):
    value = data.get(key, "")
    if not isinstance(value, str):
        raise BackendError("invalid_package_metadata", "Package metadata must contain string fields.")
    return value


def record(path, name, version="", inferred=False, output="", description="", homepage=""):
    if not valid_store_path(path) or not isinstance(name, str) or not name:
        raise BackendError("invalid_package_record", "Package records must have a name and a store output path.")
    return {
        "id": path, "storePath": path, "name": name, "version": version,
        "versionInferred": inferred, "outputName": output, "sources": [],
        "description": description, "homepage": homepage, "narSize": None,
    }


def infer_store_name(path):
    if not valid_store_path(path):
        raise BackendError("invalid_user_store_path", "User profile contains an invalid store output path.")
    basename = Path(path).name[33:]
    output = ""
    head, separator, tail = basename.rpartition("-")
    if separator and tail in OUTPUT_NAMES:
        basename, output = head, tail
    match = re.match(r"(.+?)-([0-9].*)\Z", basename)
    if match:
        name, version = match.groups()
        if "wrapper" not in name.split("-") and "wrapped" not in name.split("-"):
            return name, version, True, output
        return name, "", False, output
    return basename, "", False, output


def user_record(path, metadata=None):
    name, version, inferred, output = infer_store_name(path)
    description = homepage = ""
    if metadata is not None:
        if "pname" in metadata:
            name = text_field(metadata, "pname")
        if "version" in metadata:
            version = text_field(metadata, "version")
            inferred = False
        if "outputName" in metadata:
            output = text_field(metadata, "outputName")
        meta = metadata.get("meta", {})
        if not isinstance(meta, dict):
            raise BackendError("invalid_package_metadata", "User package metadata must be an object.")
        description = text_field(meta, "description")
        raw_homepage = meta.get("homepage", "")
        if isinstance(raw_homepage, list) and all(isinstance(item, str) for item in raw_homepage):
            homepage = " ".join(raw_homepage)
        elif isinstance(raw_homepage, str):
            homepage = raw_homepage
        else:
            raise BackendError("invalid_package_metadata", "User package homepage must be a string or string list.")
    return record(path, name, version, inferred, output, description, homepage)


def system_packages(root):
    manifest = Path(root) / "etc/cartoon-shell/system-packages.json"
    try:
        with manifest.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        raise BackendError("system_manifest_missing", "System package manifest is unavailable until the new system configuration is activated.") from None
    except (OSError, UnicodeError, ValueError, RecursionError):
        raise BackendError("system_manifest_invalid", "System package manifest could not be read as JSON.") from None
    if not isinstance(data, dict) or type(data.get("schemaVersion")) is not int or data["schemaVersion"] != SCHEMA_VERSION:
        raise BackendError("system_manifest_schema", "Unsupported system package manifest schema.")
    if not isinstance(data.get("packages"), list):
        raise BackendError("system_manifest_schema", "System package manifest must contain a packages array.")
    packages = []
    for item in data["packages"]:
        if not isinstance(item, dict) or not {"storePath", "name", "version", "outputName", "description", "homepage"} <= item.keys():
            raise BackendError("system_manifest_record", "System package manifest contains an incomplete package record.")
        packages.append(record(
            item["storePath"], text_field(item, "name"), text_field(item, "version"),
            False, text_field(item, "outputName"), text_field(item, "description"), text_field(item, "homepage"),
        ))
    return packages


def use_xdg_profiles():
    enabled = query_json(NIX + ["config", "show", "--offline", "use-xdg-base-directories"], "user_profile_settings")
    if type(enabled) is not bool:
        raise BackendError("user_profile_settings_invalid", "Nix did not return a boolean profile location setting.")
    return enabled


def profile_present(profile):
    for component in reversed((profile, *profile.parents)):
        try:
            component.lstat()
        except FileNotFoundError:
            return False
        except OSError:
            raise BackendError("user_profile_inaccessible", "User profile location could not be inspected.") from None
        try:
            if not stat.S_ISDIR(component.stat().st_mode):
                raise BackendError("user_profile_invalid", "User profile location is not a directory.")
        except FileNotFoundError:
            raise BackendError("user_profile_dangling", "User profile location contains a dangling symlink.") from None
        except OSError:
            raise BackendError("user_profile_inaccessible", "User profile location could not be accessed.") from None
    return True


def default_profile():
    home = Path.home()
    state_home = os.environ.get("NIX_STATE_HOME")
    state = Path(state_home) if state_home is not None else Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))) / "nix"
    link = state / "profile" if use_xdg_profiles() else home / ".nix-profile"
    if profile_present(link):
        return link
    profile = state / "profiles/profile"
    return profile if profile_present(profile) else None


def legacy_profile(profile):
    if (profile / "manifest.json").exists():
        return False
    manifest = profile / "manifest.nix"
    if not manifest.exists():
        return False
    try:
        contents = manifest.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        raise BackendError("user_legacy_manifest_invalid", "Legacy profile manifest could not be read.") from None
    if re.fullmatch(r"\[\s*\]", contents):
        return True
    if (contents.startswith("[") and contents.endswith("]")
            and re.search(r'\btype\s*=\s*"derivation"\s*;', contents)
            and re.search(r'\boutPath\s*=\s*"/nix/store/', contents)):
        return True
    raise BackendError("user_legacy_manifest_unknown", "Profile manifest.nix is not a recognized legacy installed-package format.")


def modern_packages(data):
    if (not isinstance(data, dict) or type(data.get("version")) is not int
            or data["version"] != 3 or not isinstance(data.get("elements"), dict)):
        raise BackendError("user_profile_schema", "Unsupported user profile JSON schema; expected version 3 elements.")
    packages = []
    for item in data["elements"].values():
        if not isinstance(item, dict) or type(item.get("active")) is not bool:
            raise BackendError("user_profile_record", "User profile contains an invalid active flag.")
        if not item["active"]:
            continue
        paths = item.get("storePaths")
        if not isinstance(paths, list) or not paths:
            raise BackendError("user_profile_record", "Active profile elements must contain store output paths.")
        for path in paths:
            packages.append(user_record(path, item))
    return packages


def legacy_packages(data):
    if not isinstance(data, dict):
        raise BackendError("user_legacy_schema", "Legacy package query must return an object.")
    packages = []
    for item in data.values():
        if not isinstance(item, dict) or not isinstance(item.get("outputs"), dict) or not item["outputs"]:
            raise BackendError("user_legacy_schema", "Legacy package query contains invalid outputs.")
        for output, path in item["outputs"].items():
            package = user_record(path, item)
            package["outputName"] = output
            packages.append(package)
    return packages


def user_packages():
    profile = default_profile()
    if profile is None:
        return [], []
    if legacy_profile(profile):
        data = query_json(["nix-env", "--profile", str(profile), "-q", "--installed", "--json", "--meta"], "user_legacy")
        return legacy_packages(data), [diagnostic("user_legacy_profile", "User packages were read from a recognized legacy nix-env profile.")]
    data = query_json(NIX + ["profile", "list", "--offline", "--json", "--profile", str(profile)], "user_profile")
    return modern_packages(data), []


def inventory(root, summary=False):
    packages = {}
    warnings = []
    errors = []
    valid_sources = 0
    for source in ("system", "user"):
        try:
            if source == "system":
                found, notes = system_packages(root), []
            else:
                found, notes = user_packages()
            valid_sources += 1
            warnings.extend(notes)
            for item in found:
                path = item["storePath"]
                if path not in packages:
                    packages[path] = item
                if source not in packages[path]["sources"]:
                    packages[path]["sources"].append(source)
        except BackendError as error:
            target = warnings if error.code == "system_manifest_missing" else errors
            target.append(diagnostic(error.code, error.message))
    records = sorted(packages.values(), key=lambda item: (item["name"].casefold(), item["version"], item["id"]))
    grouped = {source: [] for source in ("system", "user", "both")}
    for item in records:
        source = "both" if len(item["sources"]) == 2 else item["sources"][0]
        grouped[source].append(item)
    counts = {source: len(items) for source, items in grouped.items()}
    return {
        "schemaVersion": SCHEMA_VERSION, "total": len(records), "sourceCounts": counts,
        "packages": [] if summary else records,
        "groups": [] if summary else [{"id": source, "count": counts[source], "packages": items}
                                      for source, items in grouped.items()],
        "warnings": warnings, "errors": errors, "partial": valid_sources < 2,
        "available": valid_sources > 0,
    }


def path_details(path):
    data = query_json(NIX + ["path-info", "--offline", "--json", "--json-format", "2", path], "path_info")
    if (not isinstance(data, dict) or type(data.get("version")) is not int or data["version"] != 2
            or data.get("storeDir") != "/nix/store" or not isinstance(data.get("info"), dict)):
        raise BackendError("path_info_schema", "Unsupported path-info JSON format; expected version 2 for /nix/store.")
    item = data["info"].get(Path(path).name)
    if not isinstance(item, dict):
        raise BackendError("path_info_missing", "Path-info did not return the selected store output.")
    size = item.get("narSize")
    if size is not None and (type(size) is not int or size < 0):
        raise BackendError("path_info_record", "Path-info contains an invalid NAR byte size.")
    refs = item.get("references")
    if not isinstance(refs, list):
        raise BackendError("path_info_record", "Path-info contains an invalid references array.")
    references = []
    for ref in refs:
        if not isinstance(ref, str):
            raise BackendError("path_info_reference", "Path-info contains an invalid store reference.")
        candidate = ref if ref.startswith("/") else "/nix/store/" + ref
        if not valid_store_path(candidate):
            raise BackendError("path_info_reference", "Path-info contains an invalid store reference.")
        references.append(candidate)
    return size, sorted(set(references))


def info(root, selected):
    result = inventory(root)
    package = next((item for item in result["packages"] if item["id"] == selected), None) if valid_store_path(selected) else None
    response = {
        "schemaVersion": SCHEMA_VERSION, "package": package, "references": [],
        "warnings": result["warnings"], "errors": result["errors"],
        "partial": result["partial"], "available": result["available"],
    }
    if package is None:
        response["errors"].append(diagnostic("invalid_package_id", "Select a store output ID from the current package inventory."))
        response["partial"] = True
    else:
        try:
            package["narSize"], response["references"] = path_details(selected)
        except BackendError as error:
            response["errors"].append(diagnostic(error.code, error.message))
            response["partial"] = True
    return response


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise BackendError("invalid_arguments", "Expected summary|list|info, optional --system-root PATH, and --id STORE_PATH for info.")


def main(argv=None):
    parser = Parser(description="Read selected Nix profile outputs as JSON.")
    parser.add_argument("command", choices=("summary", "list", "info"))
    parser.add_argument("--system-root", default="/run/current-system")
    parser.add_argument("--id")
    try:
        args = parser.parse_args(argv)
        if (args.command == "info") != (args.id is not None):
            parser.error("--id is required only for info")
        result = info(args.system_root, args.id) if args.command == "info" else inventory(args.system_root, args.command == "summary")
        status = 0
    except BackendError as error:
        result = {
            "schemaVersion": SCHEMA_VERSION, "warnings": [],
            "errors": [diagnostic(error.code, error.message)],
            "partial": True, "available": False,
        }
        arguments = sys.argv[1:] if argv is None else argv
        if arguments and arguments[0] == "info":
            result.update(package=None, references=[])
        else:
            result.update(
                total=0, sourceCounts={"system": 0, "user": 0, "both": 0}, packages=[],
                groups=[{"id": source, "count": 0, "packages": []} for source in ("system", "user", "both")],
            )
        status = 2
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return status


if __name__ == "__main__":
    sys.exit(main())
