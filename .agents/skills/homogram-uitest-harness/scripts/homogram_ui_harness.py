from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


BUNDLE_NAME = "com.xymeng16.homogram"
ABILITY_NAME = "EntryAbility"
FIXTURE_URI = "homogram-uitest://fixture"
REMOTE_DIR = "/data/local/tmp/homogram-uitest"
CRASH_LOG_REGEX = (
    "homogram|FaultLogger|APP_CRASH|CppCrash|JsCrash|FATAL|crash|exception|"
    "SIGSEGV|SIGABRT|PROCESS_KILL|Reason:"
)
DEVICE_COMMANDS = {"launch", "dump", "screenshot", "observe", "tap-id", "input-id", "smoke"}
HDC_TARGET = os.environ.get("HOMOGRAM_HDC_TARGET")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[4]


def artifacts_dir() -> Path:
    path = repo_root() / ".agents" / "artifacts" / "uitest"
    path.mkdir(parents=True, exist_ok=True)
    return path


def run(
    args: list[str],
    cwd: Path | None = None,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    print("$ " + " ".join(args))
    completed = subprocess.run(
        args,
        cwd=str(cwd or repo_root()),
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
    )
    if completed.stdout:
        print(completed.stdout.rstrip())
    if check and completed.returncode != 0:
        raise SystemExit(completed.returncode)
    return completed


def hdc(args: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return run([*hdc_command_prefix(), *args], check=check)


def hdc_text(args: list[str]) -> str:
    completed = subprocess.run(
        [*hdc_command_prefix(), *args],
        cwd=str(repo_root()),
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return completed.stdout or ""


def hdc_command_prefix() -> list[str]:
    if HDC_TARGET:
        return ["hdc", "-t", HDC_TARGET]
    return ["hdc"]


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def bundle_name(args: argparse.Namespace) -> str:
    return getattr(args, "bundle", None) or BUNDLE_NAME


def crash_check_enabled(args: argparse.Namespace) -> bool:
    return not getattr(args, "no_crash_check", False)


def prepare_crash_window(args: argparse.Namespace) -> None:
    if not crash_check_enabled(args) or getattr(args, "no_clear_hilog", False):
        return
    hdc(["shell", "hilog", "-r"], check=False)


def force_stop_app(args: argparse.Namespace) -> None:
    if getattr(args, "keep_running", False):
        return
    hdc(["shell", "aa", "force-stop", bundle_name(args)], check=False)
    time.sleep(0.3)


def pidof_bundle(args: argparse.Namespace) -> str:
    return hdc_text(["shell", "pidof", bundle_name(args)]).strip()


def assert_app_alive(args: argparse.Namespace, reason: str) -> None:
    if not crash_check_enabled(args):
        return
    pid = pidof_bundle(args)
    if pid:
        return

    artifacts = collect_crash_info(args, reason)
    raise SystemExit(
        "Homogram process is not running after " + reason + ". Crash artifacts: " +
        ", ".join(str(path) for path in artifacts)
    )


def collect_crash_info(args: argparse.Namespace, reason: str) -> list[Path]:
    if getattr(args, "_crash_artifacts_collected", False):
        return []
    setattr(args, "_crash_artifacts_collected", True)

    stamp = timestamp()
    output_dir = artifacts_dir()
    artifacts: list[Path] = []

    def save(name: str, content: str) -> None:
        path = output_dir / f"{name}-{stamp}.txt"
        path.write_text(content, encoding="utf-8")
        artifacts.append(path)
        print(f"{name}={path}")

    bundle = bundle_name(args)
    pid = pidof_bundle(args)
    ps_output = hdc_text(["shell", "ps", "-ef"])
    matching_processes = "\n".join(line for line in ps_output.splitlines() if bundle in line)
    save("crash-process", "reason=" + reason + "\nbundle=" + bundle + "\npidof=" + pid + "\n\n" + matching_processes)

    hilog_output = hdc_text(["shell", "hilog", "-x", "-e", shell_quote(CRASH_LOG_REGEX)])
    save("crash-hilog", hilog_output)

    aa_process_output = hdc_text(["shell", "aa", "dump", "-p"])
    aa_lines = [line for line in aa_process_output.splitlines() if bundle in line or "process" in line.lower()]
    save("crash-aa-process", "\n".join(aa_lines))

    faultlog_output = hdc_text(["shell", "ls", "-la", "/data/log/faultlog/faultlogger"])
    save("crash-faultlog-ls", faultlog_output)

    print(json.dumps({"crashArtifacts": [str(path) for path in artifacts]}, indent=2))
    return artifacts


def build(args: argparse.Namespace) -> None:
    root = repo_root()
    if args.hvigor:
        hvigor = args.hvigor
    elif os.environ.get("HOMOGRAM_HVIGOR"):
        hvigor = os.environ["HOMOGRAM_HVIGOR"]
    elif (root / "hvigorw").exists():
        hvigor = str(root / "hvigorw")
    elif (root / "hvigorw.bat").exists():
        hvigor = str(root / "hvigorw.bat")
    elif shutil.which("hvigorw"):
        hvigor = "hvigorw"
    else:
        raise SystemExit(
            "Could not find hvigorw. Pass --hvigor <path>, set HOMOGRAM_HVIGOR, "
            "or run from a DevEco Studio terminal where hvigorw is on PATH."
        )

    command = [
        hvigor,
        "--mode",
        "module",
        "--no-daemon",
        "-p",
        "module=phone@default",
        "-p",
        "product=default",
        "-p",
        "requiredDeviceType=phone",
        "-p",
        "buildMode=uitest",
        "assembleHap",
    ]
    run(command, cwd=root, env=build_env(hvigor))


def build_env(hvigor: str) -> dict[str, str]:
    env = os.environ.copy()
    dev_eco_root = find_dev_eco_root(hvigor)
    if dev_eco_root is None:
        return env

    node_home = dev_eco_root / "tools" / "node"
    java_home = dev_eco_root / "jbr"
    sdk_root = dev_eco_root / "sdk"
    sdk_home = sdk_root / "default"
    openharmony_home = sdk_home / "openharmony"
    hms_home = sdk_home / "hms"

    if node_home.exists():
        set_path_env(env, "NODE_HOME", node_home)
        env["PATH"] = str(node_home) + os.pathsep + env.get("PATH", "")
    if (java_home / "bin" / "java.exe").exists() or (java_home / "bin" / "java").exists():
        set_path_env(env, "JAVA_HOME", java_home)
        env["PATH"] = str(java_home / "bin") + os.pathsep + env.get("PATH", "")
    if sdk_root.exists():
        set_harmony_sdk_env(env, "DEVECO_SDK_HOME", sdk_root)
        set_harmony_sdk_env(env, "HOS_SDK_HOME", sdk_root)
    if openharmony_home.exists():
        set_sdk_env(env, "OHOS_BASE_SDK_HOME", openharmony_home)

    return env


def set_path_env(env: dict[str, str], key: str, value: Path) -> None:
    current = env.get(key)
    if current and Path(current).exists():
        return
    env[key] = str(value)


def set_sdk_env(env: dict[str, str], key: str, value: Path) -> None:
    current = env.get(key)
    if current and sdk_components_exist(Path(current)):
        return
    env[key] = str(value)


def set_harmony_sdk_env(env: dict[str, str], key: str, value: Path) -> None:
    current = env.get(key)
    if current and harmony_sdk_root_exists(Path(current)):
        return
    env[key] = str(value)


def harmony_sdk_root_exists(path: Path) -> bool:
    return any(child.is_dir() and (child / "sdk-pkg.json").exists() for child in path.glob("*"))


def sdk_components_exist(path: Path) -> bool:
    return all((path / name).exists() for name in ("ets", "js", "native", "previewer", "toolchains"))


def find_dev_eco_root(hvigor: str) -> Path | None:
    hvigor_path = Path(hvigor)
    if not hvigor_path.exists():
        resolved = shutil.which(hvigor)
        if resolved is None:
            return None
        hvigor_path = Path(resolved)

    try:
        hvigor_path = hvigor_path.resolve()
    except OSError:
        pass

    for candidate in (hvigor_path, *hvigor_path.parents):
        if (candidate / "sdk" / "default").exists() and (candidate / "tools" / "node").exists():
            return candidate
    return None


def latest_hap() -> Path:
    root = repo_root()
    candidates = list((root / "products" / "phone" / "build").glob("**/*signed*.hap"))
    if not candidates:
        candidates = list((root / "products" / "phone" / "build").glob("**/*.hap"))
    if not candidates:
        raise SystemExit("No HAP found. Run the build command first.")
    return max(candidates, key=lambda p: p.stat().st_mtime)


def install(args: argparse.Namespace) -> None:
    hap = Path(args.hap).resolve() if args.hap else latest_hap()
    hdc(["install", "-r", str(hap)])


def launch(args: argparse.Namespace) -> None:
    force_stop_app(args)
    prepare_crash_window(args)
    uri = getattr(args, "uri", None) or FIXTURE_URI
    hdc(["shell", "aa", "start", "-b", args.bundle, "-a", args.ability, "-U", uri])
    time.sleep(args.wait)
    assert_app_alive(args, "launch")


def ensure_remote_dir() -> None:
    hdc(["shell", "mkdir", "-p", REMOTE_DIR], check=False)


def recv(remote: str, local: Path) -> None:
    hdc(["file", "recv", remote, str(local)])


def dump_layout(args: argparse.Namespace) -> Path:
    ensure_remote_dir()
    stamp = timestamp()
    remote = f"{REMOTE_DIR}/layout-{stamp}.json"
    local = artifacts_dir() / f"layout-{stamp}.json"
    hdc(["shell", "uitest", "dumpLayout", "-p", remote])
    recv(remote, local)
    print(f"layout={local}")
    return local


def screenshot(args: argparse.Namespace) -> Path:
    ensure_remote_dir()
    stamp = timestamp()
    remote = f"{REMOTE_DIR}/screen-{stamp}.png"
    local = artifacts_dir() / f"screen-{stamp}.png"
    hdc(["shell", "uitest", "screenCap", "-p", remote])
    recv(remote, local)
    print(f"screenshot={local}")
    return local


def observe(args: argparse.Namespace) -> None:
    if getattr(args, "expect_app", False):
        assert_app_alive(args, "observe")
    layout = dump_layout(args)
    screen = screenshot(args)
    print(json.dumps({"layout": str(layout), "screenshot": str(screen)}, indent=2))


def tap_id(args: argparse.Namespace) -> None:
    layout_path = dump_layout(args)
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    match = find_node(layout, args.selector)
    if match is None:
        raise SystemExit(f"Could not find selector in layout: {args.selector}")
    bounds = extract_bounds(match)
    if bounds is None:
        raise SystemExit(f"Found selector but could not extract bounds: {args.selector}")
    x = (bounds[0] + bounds[2]) // 2
    y = (bounds[1] + bounds[3]) // 2
    print(json.dumps({"selector": args.selector, "bounds": bounds, "tap": [x, y]}, indent=2))
    hdc(["shell", "uitest", "uiInput", "click", str(x), str(y)])


def input_id(args: argparse.Namespace) -> None:
    tap_args = argparse.Namespace(selector=args.selector)
    tap_id(tap_args)
    time.sleep(args.wait)
    hdc(["shell", "uitest", "uiInput", "text", args.text])


def smoke(args: argparse.Namespace) -> None:
    args.expect_app = True
    launch(args)
    observe(args)
    chat_args = argparse.Namespace(selector="hg-chat-row-1001")
    tap_id(chat_args)
    time.sleep(1)
    assert_app_alive(args, "opening fixture chat")
    observe(args)
    input_args = argparse.Namespace(selector="hg-composer-input", text="hello from Homogram UITest harness", wait=0.4)
    input_id(input_args)
    time.sleep(0.4)
    assert_app_alive(args, "typing fixture message")
    send_args = argparse.Namespace(selector="hg-composer-send-button")
    tap_id(send_args)
    time.sleep(1)
    assert_app_alive(args, "sending fixture message")
    observe(args)


def crash_info(args: argparse.Namespace) -> None:
    collect_crash_info(args, "manual crash-info")


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def find_node(value: Any, selector: str) -> dict[str, Any] | None:
    if isinstance(value, dict):
        if node_matches(value, selector):
            return value
        for child in value.values():
            match = find_node(child, selector)
            if match is not None:
                return match
    elif isinstance(value, list):
        for child in value:
            match = find_node(child, selector)
            if match is not None:
                return match
    return None


def node_matches(node: dict[str, Any], selector: str) -> bool:
    interesting_keys = {
        "id",
        "key",
        "componentId",
        "accessibilityId",
        "inspectorKey",
        "resourceId",
        "text",
        "accessibilityText",
        "description",
    }
    for key, value in node.items():
        if key in interesting_keys and isinstance(value, str) and value == selector:
            return True
        if isinstance(value, dict) and node_matches(value, selector):
            return True
    return False


def extract_bounds(node: dict[str, Any]) -> tuple[int, int, int, int] | None:
    for key in ("bounds", "rect", "visibleBounds", "screenBounds"):
        value = node.get(key)
        parsed = parse_bounds_value(value)
        if parsed is not None:
            return parsed

    attrs = node.get("attributes")
    if isinstance(attrs, dict):
        parsed = extract_bounds(attrs)
        if parsed is not None:
            return parsed

    left = number_from_any(node.get("left") or node.get("x"))
    top = number_from_any(node.get("top") or node.get("y"))
    right = number_from_any(node.get("right"))
    bottom = number_from_any(node.get("bottom"))
    width = number_from_any(node.get("width"))
    height = number_from_any(node.get("height"))

    if left is not None and top is not None and right is not None and bottom is not None:
        return (left, top, right, bottom)
    if left is not None and top is not None and width is not None and height is not None:
        return (left, top, left + width, top + height)
    return None


def parse_bounds_value(value: Any) -> tuple[int, int, int, int] | None:
    if isinstance(value, dict):
        return extract_bounds(value)
    if isinstance(value, list) and len(value) >= 4:
        nums = [number_from_any(item) for item in value[:4]]
        if all(item is not None for item in nums):
            return (nums[0], nums[1], nums[2], nums[3])  # type: ignore[arg-type]
    if isinstance(value, str):
        nums = [int(item) for item in re.findall(r"-?\d+", value)]
        if len(nums) >= 4:
            return (nums[0], nums[1], nums[2], nums[3])
    return None


def number_from_any(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        match = re.search(r"-?\d+", value)
        if match:
            return int(match.group(0))
    return None


def main(argv: list[str]) -> int:
    global HDC_TARGET
    parser = argparse.ArgumentParser(description="Homogram hdc UITest harness")
    parser.add_argument("--bundle", default=os.environ.get("HOMOGRAM_BUNDLE", BUNDLE_NAME))
    parser.add_argument("--ability", default=os.environ.get("HOMOGRAM_ABILITY", ABILITY_NAME))
    parser.add_argument("--target", default=os.environ.get("HOMOGRAM_HDC_TARGET"))
    parser.add_argument("--wait", type=float, default=1.5)
    parser.add_argument("--no-crash-check", action="store_true")
    parser.add_argument("--no-clear-hilog", action="store_true")
    parser.add_argument("--keep-running", action="store_true")

    sub = parser.add_subparsers(dest="command", required=True)

    build_parser = sub.add_parser("build")
    build_parser.add_argument("--hvigor")
    build_parser.set_defaults(func=build)

    install_parser = sub.add_parser("install")
    install_parser.add_argument("--hap")
    install_parser.set_defaults(func=install)

    launch_parser = sub.add_parser("launch")
    launch_parser.add_argument("--uri", default=FIXTURE_URI)
    launch_parser.set_defaults(func=launch)

    sub.add_parser("dump").set_defaults(func=dump_layout)
    sub.add_parser("screenshot").set_defaults(func=screenshot)
    sub.add_parser("observe").set_defaults(func=observe)
    sub.add_parser("crash-info").set_defaults(func=crash_info)

    tap_parser = sub.add_parser("tap-id")
    tap_parser.add_argument("selector")
    tap_parser.set_defaults(func=tap_id)

    input_parser = sub.add_parser("input-id")
    input_parser.add_argument("selector")
    input_parser.add_argument("text")
    input_parser.set_defaults(func=input_id)

    sub.add_parser("smoke").set_defaults(func=smoke)

    args = parser.parse_args(argv)
    HDC_TARGET = args.target
    try:
        result = args.func(args)
    except SystemExit as exc:
        if args.command in DEVICE_COMMANDS and crash_check_enabled(args) and exc.code not in (0, None):
            collect_crash_info(args, args.command + " failed")
        raise
    if isinstance(result, Path):
        print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
