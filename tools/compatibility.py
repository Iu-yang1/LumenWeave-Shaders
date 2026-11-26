"""Version target metadata and deterministic shader entry-point adaptation."""
import re

TARGETS = {
    "1.20.x": {"minecraft": "1.20–1.20.6", "java": "17 (1.20–1.20.4), 21 (1.20.5–1.20.6)",
               "loader": "matching Iris/Sodium; optional capabilities negotiated at runtime"},
    "1.21.x": {"minecraft": "1.21–1.21.11", "java": "21",
               "loader": "matching Iris/Sodium; explicit dimension mapping"},
    "26.x": {"minecraft": "26.1–26.3", "java": "25",
             "loader": "matching Iris/Sodium; OpenGL; modern indirect dispatch when supported"},
}
ENTRY_SUFFIXES = (".fsh", ".vsh", ".csh")
DIMENSION_DEFINES = {"world-1": "LW_DIMENSION_NETHER", "world1": "LW_DIMENSION_END"}
INCLUDE = re.compile(r'^\s*#include\s+"(/[^"]+)"\s*$')


def dimension_entry(members, name, marker):
    """Hoist the shared program version, leaving its nested absolute includes intact."""
    source = members[name].decode("utf-8")
    visited = {name}
    while not source.lstrip().startswith("#version"):
        match = INCLUDE.fullmatch(source.strip())
        if not match:
            raise ValueError(f"Entry point has no leading version: {name}")
        shared = "shaders" + match.group(1)
        if shared in visited:
            raise ValueError(f"Entry include cycle: {name}")
        visited.add(shared)
        source = members[shared].decode("utf-8")
    source = source.lstrip()
    if re.search(rf"(?m)^#define {marker}(?:\s|$)", source):
        return source.encode("utf-8")
    version, newline, body = source.partition("\n")
    return (version + newline + f"#define {marker}\n" + body).encode("utf-8")


def adapt_members(members, target=None):
    result = dict(members)
    for name in sorted(members):
        parts = name.split("/")
        if len(parts) == 3 and parts[1] in DIMENSION_DEFINES and name.endswith(ENTRY_SUFFIXES):
            result[name] = dimension_entry(members, name, DIMENSION_DEFINES[parts[1]])
    if target == "1.20.x":
        # Legacy worldN mapping is recognized even by pre-dimension.properties Iris.
        result.pop("shaders/dimension.properties", None)
    if target is not None:
        if target not in TARGETS:
            raise ValueError(f"Unknown target: {target}")
        info = TARGETS[target]
        result["COMPATIBILITY.txt"] = (
            f"LumenWeave shader pack target: {info['minecraft']}\n"
            f"Java: {info['java']}\nLoader: {info['loader']}\n"
            "Target range is a compatibility objective, not a runtime certification.\n"
            "Install this inner ZIP directly in shaderpacks. Do not install the outer bundle.\n"
        ).encode("utf-8")
    return result
