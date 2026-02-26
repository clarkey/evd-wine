#!/bin/bash
set -e

APP_DIR="/home/wineuser/app"

# ---------------------------------------------------------------------------
# Validate that the ExportVaultData application has been volume-mounted
# ---------------------------------------------------------------------------
validate_app_dir() {
    local missing=()

    if [ ! -f "$APP_DIR/ExportVaultData.exe" ]; then
        missing+=("ExportVaultData.exe")
    fi
    if [ ! -f "$APP_DIR/Vault.ini" ]; then
        missing+=("Vault.ini")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Required files not found in $APP_DIR:" >&2
        for f in "${missing[@]}"; do
            echo "  - $f" >&2
        done
        echo "" >&2
        echo "The ExportVaultData application files must be volume-mounted into the container." >&2
        echo "Example:" >&2
        echo "  docker run -v /path/to/ExportVaultData:/home/wineuser/app evd-wine ExportVaultData ..." >&2
        echo "" >&2
        echo "The mount should contain at minimum:" >&2
        echo "  ExportVaultData.exe    - Main executable" >&2
        echo "  Vault.ini              - Vault connection settings" >&2
        echo "  CyberArk.Casos.dll     - CyberArk SDK library" >&2
        echo "  CreateCredFile/        - Credential file creation utility" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Fix ownership/permissions of volume-mounted directories
# ---------------------------------------------------------------------------
mkdir -p "$APP_DIR/output" "$APP_DIR/creds" 2>/dev/null || true
chown -R wineuser:wineuser "$APP_DIR/output" "$APP_DIR/creds" 2>/dev/null || true
chmod -R u+rwX "$APP_DIR/output" "$APP_DIR/creds" 2>/dev/null || true

# Suppress Wine/Xvfb runtime warnings
export XDG_RUNTIME_DIR="/tmp/xdg-runtime"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo "=== CyberArk Export Vault Data (EVD) - Wine Container ==="
    echo ""
    echo "This container provides the Wine runtime for ExportVaultData."
    echo "The application files must be volume-mounted at $APP_DIR."
    echo ""
    echo "Usage:"
    echo "  ExportVaultData  - Run ExportVaultData.exe with given args"
    echo "  CreateCredFile   - Run CreateCredFile.exe with given args"
    echo "  bash             - Drop into a shell"
    echo "  <any .exe>       - Run arbitrary exe under Wine"
    echo ""
    echo "Examples:"
    echo "  docker run -v /path/to/ExportVaultData:/home/wineuser/app evd-wine ExportVaultData /?"
    echo "  docker run -v /path/to/ExportVaultData:/home/wineuser/app evd-wine CreateCredFile user.cred Password"
    echo "  docker run -v /path/to/ExportVaultData:/home/wineuser/app evd-wine bash"
    echo ""
    exit 0
fi

CMD="$1"
shift

case "$CMD" in
    ExportVaultData)
        validate_app_dir
        exec gosu wineuser wine "$APP_DIR/ExportVaultData.exe" "$@"
        ;;
    CreateCredFile)
        if [ ! -f "$APP_DIR/CreateCredFile/CreateCredFile.exe" ]; then
            echo "ERROR: CreateCredFile.exe not found at $APP_DIR/CreateCredFile/" >&2
            echo "Ensure the CreateCredFile directory is included in your volume mount." >&2
            exit 1
        fi
        exec gosu wineuser wine "$APP_DIR/CreateCredFile/CreateCredFile.exe" "$@"
        ;;
    bash|sh)
        exec gosu wineuser /bin/bash "$@"
        ;;
    *.exe)
        if [ ! -f "$APP_DIR/$CMD" ]; then
            echo "ERROR: $CMD not found in $APP_DIR" >&2
            echo "Ensure the file is included in your volume mount." >&2
            exit 1
        fi
        exec gosu wineuser wine "$APP_DIR/$CMD" "$@"
        ;;
    *)
        # Pass everything directly to wine as a fallback
        exec gosu wineuser wine "$CMD" "$@"
        ;;
esac
