#!/bin/bash
set -e

APP_DIR="/home/wineuser/app"

# Fix ownership of volume-mounted directories so wineuser can read/write them
chown -R wineuser:wineuser "$APP_DIR/output" 2>/dev/null || true
chown -R wineuser:wineuser "$APP_DIR/creds" 2>/dev/null || true

# Suppress Wine/Xvfb runtime warnings
export XDG_RUNTIME_DIR="/tmp/xdg-runtime"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo "=== CyberArk Export Vault Data (EVD) - Wine Container ==="
    echo ""
    echo "Usage:"
    echo "  ExportVaultData  - Run ExportVaultData.exe with given args"
    echo "  CreateCredFile   - Run CreateCredFile.exe with given args"
    echo "  bash             - Drop into a shell"
    echo "  <any .exe>       - Run arbitrary exe under Wine"
    echo ""
    echo "Examples:"
    echo "  docker run evd-wine ExportVaultData /?"
    echo "  docker run evd-wine CreateCredFile user.cred Password /username admin /password pass"
    echo "  docker run -v \$(pwd)/output:/home/wineuser/app/output evd-wine ExportVaultData <args>"
    echo ""
    exit 0
fi

CMD="$1"
shift

case "$CMD" in
    ExportVaultData)
        exec gosu wineuser wine "$APP_DIR/ExportVaultData.exe" "$@"
        ;;
    CreateCredFile)
        exec gosu wineuser wine "$APP_DIR/CreateCredFile/CreateCredFile.exe" "$@"
        ;;
    bash|sh)
        exec gosu wineuser /bin/bash "$@"
        ;;
    *.exe)
        exec gosu wineuser wine "$APP_DIR/$CMD" "$@"
        ;;
    *)
        # Pass everything directly to wine as a fallback
        exec gosu wineuser wine "$CMD" "$@"
        ;;
esac
