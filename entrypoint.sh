#!/bin/bash
set -e

APP_DIR="/home/wineuser/app"
EVD_DIR="$APP_DIR/ExportVaultData"

# ---------------------------------------------------------------------------
# Validate that the ExportVaultData application has been volume-mounted
# ---------------------------------------------------------------------------
validate_evd_dir() {
    if [ ! -d "$EVD_DIR" ]; then
        echo "ERROR: ExportVaultData directory not found at $EVD_DIR" >&2
        echo "" >&2
        echo "The ExportVaultData application must be volume-mounted into the container." >&2
        echo "Example:" >&2
        echo "  docker run -v /path/to/ExportVaultData:$EVD_DIR evd-wine ExportVaultData ..." >&2
        exit 1
    fi

    local missing=()

    if [ ! -f "$EVD_DIR/ExportVaultData.exe" ]; then
        missing+=("ExportVaultData.exe")
    fi
    if [ ! -f "$EVD_DIR/Vault.ini" ]; then
        missing+=("Vault.ini")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Required files not found in $EVD_DIR:" >&2
        for f in "${missing[@]}"; do
            echo "  - $f" >&2
        done
        echo "" >&2
        echo "The volume mount should contain at minimum:" >&2
        echo "  ExportVaultData.exe              - Main executable" >&2
        echo "  Vault.ini                        - Vault connection settings" >&2
        echo "  CyberArk.Casos.dll               - CyberArk SDK library" >&2
        echo "  CyberArk.Services.Exceptions.dll - CyberArk exceptions library" >&2
        echo "  CreateCredFile/                   - Credential file creation utility" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Fix ownership/permissions of volume-mounted directories
# ---------------------------------------------------------------------------
mkdir -p "$APP_DIR/logs" "$APP_DIR/exports" "$APP_DIR/creds" 2>/dev/null || true
chown -R wineuser:wineuser "$APP_DIR/logs" "$APP_DIR/exports" "$APP_DIR/creds" 2>/dev/null || true
chmod -R u+rwX "$APP_DIR/logs" "$APP_DIR/exports" "$APP_DIR/creds" 2>/dev/null || true

# Suppress Wine/Xvfb runtime warnings
export XDG_RUNTIME_DIR="/tmp/xdg-runtime"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo "=== CyberArk Export Vault Data (EVD) - Wine Container ==="
    echo ""
    echo "This container provides the Wine runtime for ExportVaultData."
    echo "The application must be volume-mounted at $EVD_DIR."
    echo ""
    echo "Usage:"
    echo "  ExportVaultData  - Run ExportVaultData.exe with given args"
    echo "  CreateCredFile   - Run CreateCredFile.exe with given args"
    echo "  bash             - Drop into a shell"
    echo "  <any .exe>       - Run arbitrary exe under Wine"
    echo ""
    echo "Examples:"
    echo "  docker run -v /path/to/ExportVaultData:$EVD_DIR evd-wine ExportVaultData /?"
    echo "  docker run -v /path/to/ExportVaultData:$EVD_DIR evd-wine CreateCredFile user.cred Password"
    echo "  docker run -v /path/to/ExportVaultData:$EVD_DIR evd-wine bash"
    echo ""
    exit 0
fi

CMD="$1"
shift

# Ensure Wine's working directory is APP_DIR so all relative paths
# (creds/, logs/, exports/, ExportVaultData/Vault.ini) resolve from there.
cd "$APP_DIR"

case "$CMD" in
    ExportVaultData)
        validate_evd_dir
        exec gosu wineuser wine "$EVD_DIR/ExportVaultData.exe" "$@"
        ;;
    CreateCredFile)
        if [ ! -d "$EVD_DIR" ]; then
            echo "ERROR: ExportVaultData directory not found at $EVD_DIR" >&2
            echo "Mount it with: -v /path/to/ExportVaultData:$EVD_DIR" >&2
            exit 1
        fi
        if [ ! -f "$EVD_DIR/CreateCredFile/CreateCredFile.exe" ]; then
            echo "ERROR: CreateCredFile.exe not found at $EVD_DIR/CreateCredFile/" >&2
            echo "Ensure the CreateCredFile directory is included in your ExportVaultData volume." >&2
            exit 1
        fi
        exec gosu wineuser wine "$EVD_DIR/CreateCredFile/CreateCredFile.exe" "$@"
        ;;
    bash|sh)
        exec gosu wineuser /bin/bash "$@"
        ;;
    *.exe)
        if [ ! -f "$EVD_DIR/$CMD" ]; then
            echo "ERROR: $CMD not found in $EVD_DIR" >&2
            echo "Ensure the file is included in your ExportVaultData volume." >&2
            exit 1
        fi
        exec gosu wineuser wine "$EVD_DIR/$CMD" "$@"
        ;;
    *)
        # Pass everything directly to wine as a fallback
        exec gosu wineuser wine "$CMD" "$@"
        ;;
esac
