#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CASES_DIR = ROOT / "test" / "cases"
OUTPUT = ROOT / "ContractTest.roc"


Env = list[dict[str, str]]


def load_json(name: str) -> Any:
    with (CASES_DIR / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def roc_str(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        .replace("${", "\\${")
    )
    return f'"{escaped}"'


def roc_env(env: Env) -> str:
    if not env:
        return "[]"

    entries = [
        f'{{ key: {roc_str(item["key"])}, value: {roc_str(item["value"])} }}'
        for item in env
    ]
    return f"[{', '.join(entries)}]"


def roc_env_files(files: list[Env]) -> str:
    return f"[{', '.join(roc_env(env) for env in files)}]"


def roc_str_list(items: list[str]) -> str:
    return f"[{', '.join(roc_str(item) for item in items)}]"


def roc_fake_files(files: list[dict[str, Any]], fixtures: dict[str, str]) -> str:
    entries = []

    for item in files:
        if item["type"] == "file":
            content = (
                fixtures[item["fixture"]] if "fixture" in item else item["content"]
            )
            source = f"File({roc_str(content)})"
        elif item["type"] == "directory":
            source = "Directory"
        else:
            raise ValueError(f"Unknown fake file type: {item['type']}")

        entries.append(f"{{ path: {roc_str(item['path'])}, source: {source} }}")

    return f"[{', '.join(entries)}]"


def comment(text: str) -> str:
    safe = text.replace("\n", " ").replace("\r", " ")
    return f"# {safe}"


def parse_expect(case: dict[str, Any], fixtures: dict[str, str]) -> list[str]:
    input_value = fixtures[case["fixture"]] if "fixture" in case else case["input"]
    existing_env = case.get("existingEnv", [])

    if "expectedError" in case:
        expected = f'Err({case["expectedError"]})'
    else:
        expected = f'Ok({roc_env(case["expected"])})'

    return [
        comment(case["name"]),
        "expect",
        f"    Dotenv.parseString({roc_str(input_value)}, {roc_env(existing_env)}) == {expected}",
        "",
    ]


def marshal_expect(case: dict[str, Any]) -> list[str]:
    return [
        comment(case["name"]),
        "expect",
        f"    Dotenv.marshalEnv({roc_env(case['env'])}) == Ok({roc_str(case['expected'])})",
        "",
    ]


def apply_expect(case: dict[str, Any]) -> list[str]:
    operation = case["operation"]

    if operation == "mergeParsedFiles":
        expression = (
            f"Dotenv.mergeParsedFiles({roc_env_files(case['files'])})"
            f" == {roc_env(case['expected'])}"
        )
    elif operation == "applyParsedEnv":
        expression = (
            f"Dotenv.applyParsedEnv({roc_env(case['parsedEnv'])}, "
            f"{roc_env(case['existingEnv'])}, {case['policy']})"
            f" == {roc_env(case['expected'])}"
        )
    else:
        raise ValueError(f"Unknown apply operation: {operation}")

    return [comment(case["name"]), "expect", f"    {expression}", ""]


def roundtrip_expect(case: dict[str, Any], fixtures: dict[str, str]) -> list[str]:
    input_value = fixtures[case["fixture"]] if "fixture" in case else case["input"]

    return [
        comment(case["name"]),
        "expect",
        f"    when Dotenv.parseString({roc_str(input_value)}, []) is",
        "        Ok(env) ->",
        "            when Dotenv.marshalEnv(env) is",
        "                Ok(serialized) ->",
        "                    Dotenv.parseString(serialized, []) == Ok(env)",
        "                Err(_) ->",
        "                    Bool.false",
        "        Err(_) ->",
        "            Bool.false",
        "",
    ]


def io_expect(case: dict[str, Any], fixtures: dict[str, str]) -> list[str]:
    paths = roc_str_list(case["paths"])
    files = roc_fake_files(case["files"], fixtures)
    existing_env = roc_env(case.get("existingEnv", []))
    operation = case["operation"]

    if operation not in ["readFiles", "loadEnv", "overloadEnv"]:
        raise ValueError(f"Unknown I/O operation: {operation}")

    if "expectedError" in case:
        error = case["expectedError"]
        expected = f'Err({error["tag"]}({roc_str(error["path"])}))'
    else:
        expected = f'Ok({roc_env(case["expected"])})'

    return [
        comment(case["name"]),
        "expect",
        f"    Dotenv.{operation}({paths}, {files}, {existing_env}) == {expected}",
        "",
    ]


def main() -> None:
    fixtures = load_json("fixtures.json")
    parse_cases = load_json("parse.json")
    marshal_cases = load_json("marshal.json")
    apply_cases = load_json("apply.json")
    roundtrip_cases = load_json("roundtrip.json")
    io_cases = load_json("io.json")

    lines = [
        "module []",
        "",
        "import Dotenv",
        "",
        "# Generated by scripts/generate_roc_tests.py from test/cases/*.json.",
        "# Edit the JSON contract cases, then regenerate this file.",
        "",
    ]

    for case in parse_cases:
        lines.extend(parse_expect(case, fixtures))

    for case in marshal_cases:
        lines.extend(marshal_expect(case))

    for case in apply_cases:
        lines.extend(apply_expect(case))

    for case in roundtrip_cases:
        lines.extend(roundtrip_expect(case, fixtures))

    for case in io_cases:
        lines.extend(io_expect(case, fixtures))

    OUTPUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
