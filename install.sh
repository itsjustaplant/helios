#!/bin/sh
# Download, build, and install a standalone copy of Helios.
set -eu

usage() {
  cat <<'EOF'
Usage: sh install.sh [--app-dir DIRECTORY] [--ref BRANCH_OR_TAG] [--no-open]

Build and install Helios from GitHub, then open it.
  --app-dir DIRECTORY  Install here (default: /Applications)
  --ref BRANCH_OR_TAG  Build this branch or release tag (default: master)
  --no-open           Install without launching Helios
  -h, --help          Show this help
EOF
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

app_dir=/Applications
source_ref=master
launch_app=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app-dir|--ref)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "Missing value for $1"
      case "$1" in
        --app-dir) app_dir=$2 ;;
        --ref) source_ref=$2 ;;
      esac
      shift 2
      ;;
    --no-open) launch_app=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] ||
  fail 'Helios requires an Apple Silicon Mac.'
[ "$(id -u)" -ne 0 ] || fail 'Run this script as your regular user, without sudo.'
os_major=$(sw_vers -productVersion | cut -d . -f 1)
[ "$os_major" -ge 13 ] || fail 'Helios requires macOS 13 or later.'

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  fail "Complete Apple's developer-tools installer, then run this script again. Swift 6.2 or later is required."
fi
for tool in git python3 swift; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool is missing: $tool. Install a compatible Xcode or Command Line Tools release."
done
python3 - <<'PY'
import re
import subprocess
import sys

result = subprocess.run(["swift", "--version"], check=True, text=True, capture_output=True)
version = re.search(r"Swift version (\d+)\.(\d+)", result.stdout)
if not version or tuple(map(int, version.groups())) < (6, 2):
    sys.exit("Swift 6.2 or later is required. Update Xcode or Command Line Tools, then run this script again.")
PY

# Resolve the destination before the temporary checkout is created.
app_dir=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve())' "$app_dir")
helios_source_dir=$(mktemp -d "${TMPDIR:-/tmp}/helios-install.XXXXXX")
trap 'rm -rf -- "$helios_source_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Downloading Helios (%s)…\n' "$source_ref"
git clone --depth 1 --branch "$source_ref" -- https://github.com/itsjustaplant/helios.git "$helios_source_dir/source"
python3 "$helios_source_dir/source/scripts/install-app.py" --app-dir "$app_dir"

if [ "$launch_app" = true ]; then
  open "$app_dir/Helios.app"
fi
