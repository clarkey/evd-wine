# EVD Wine Container

Docker container that runs the CyberArk **Export Vault Data (EVD)** utility v12.2 under Wine on Linux. The EVD utility exports data from a CyberArk Vault to TXT/CSV files or to an MSSQL database.

## What's inside

- **[scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine)** base image (Ubuntu 22.04 + WineHQ stable)
- **Microsoft Visual C++ Redistributable 2015-2022** (x86 + x64) — installed via winetricks
- **.NET Framework 4.8 Runtime** — installed via winetricks
- **ExportVaultData.exe** and **CreateCredFile.exe** from the EVD v12.2 release

These are the software prerequisites specified in the [CyberArk EVD system requirements](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20sysreq/system%20requirements%20-%20evd.htm).

## Prerequisites

- Docker
- **Must be built on an amd64 (x86_64) host.** Wine cannot run under QEMU emulation on ARM (Apple Silicon), so building on macOS with `--platform linux/amd64` will fail. Use a Linux amd64 VM or CI runner.
- **CyberArk EVD utility** — the EVD binaries are not included in this repo (vendor software). Obtain the `ExportVaultData` release from your CyberArk representative and place the contents in an `ExportVaultData/` directory at the repo root.

## Build

1. Place EVD files in the `ExportVaultData/` directory:

```
ExportVaultData/
├── ExportVaultData.exe
├── CreateCredFile/
│   └── CreateCredFile.exe
├── Vault.ini
├── *.dll
└── ...
```

2. Build the image:

```bash
docker build --platform linux/amd64 -t evd-wine .
```

> **Note:** The first build takes a long time (30+ minutes). The `.NET 4.8` winetricks installation is the bottleneck — it downloads and installs multiple .NET versions as prerequisites. This is a one-time cost baked into the image. Subsequent rebuilds that only change the app files or entrypoint will be instant due to Docker layer caching.

## Configuration

Before running the EVD utility, you need to:

1. **Edit `Vault.ini`** with your Vault connection details (address, port, etc.)
2. **Create a credential file** using `CreateCredFile.exe`

You can either:
- Edit `Vault.ini` before building the image (it gets baked in)
- Bind-mount a `Vault.ini` at runtime (recommended)

## Usage

Running the container with no arguments prints help:

```bash
docker run --rm evd-wine
```

### Show ExportVaultData usage

```bash
docker run --rm evd-wine ExportVaultData /?
```

### Create a credential file

```bash
docker run --rm \
  -v $(pwd)/output:/home/wineuser/app/output \
  evd-wine CreateCredFile output/user.cred Password \
    /username <username> \
    /password <password>
```

### Run an export

```bash
docker run --rm \
  -v $(pwd)/Vault.ini:/home/wineuser/app/Vault.ini:ro \
  -v $(pwd)/user.cred:/home/wineuser/app/user.cred:ro \
  -v $(pwd)/output:/home/wineuser/app/output \
  evd-wine ExportVaultData \
    \\VaultFile=Vault.ini \
    \\CredFile=user.cred \
    \\LogFile=output/evd.log \
    \\Target=FILE \
    \\safeslist=output/safes.csv
```

### Available entrypoint commands

| Command | Description |
|---|---|
| `ExportVaultData [args]` | Runs `ExportVaultData.exe` under Wine |
| `CreateCredFile [args]` | Runs `CreateCredFile/CreateCredFile.exe` under Wine |
| `bash` | Drops into a bash shell |
| `<name>.exe [args]` | Runs the named `.exe` from the app directory under Wine |

## Debugging

### Interactive shell

```bash
docker run --rm -it evd-wine bash
```

From inside the container you can run commands manually:

```bash
# Run the exe directly
wine /home/wineuser/app/ExportVaultData.exe /?

# Check Wine configuration
wine --version
winetricks list-installed

# Inspect the Wine prefix
ls -la ~/.wine/drive_c/
```

### Enable Wine debug output

The `WINEDEBUG` environment variable is set to `-all` (silent) by default. Override it to get verbose Wine logging:

```bash
# All debug output
docker run --rm -e WINEDEBUG=+all evd-wine ExportVaultData /?

# Only DLL loading messages
docker run --rm -e WINEDEBUG=+loaddll evd-wine ExportVaultData /?

# Relay traces (very verbose)
docker run --rm -e WINEDEBUG=+relay evd-wine ExportVaultData /?
```

### Check installed dependencies

```bash
docker run --rm -it evd-wine bash
winetricks list-installed
# Should show: dotnet48 vcrun2022
```

### Network connectivity

The EVD utility connects to the Vault over TCP (default port 1858). Make sure the container can reach the Vault:

```bash
# Use host networking (simplest for connectivity)
docker run --rm --network host evd-wine ExportVaultData <args>

# Or specify DNS
docker run --rm --dns 10.0.0.1 evd-wine ExportVaultData <args>
```

### Build cache issues

If the build fails partway through winetricks installations, Docker's layer cache should let you resume from the last successful step. To force a clean rebuild:

```bash
docker build --platform linux/amd64 --no-cache -t evd-wine .
```

## File structure

```
.
├── Dockerfile
├── entrypoint.sh
├── .dockerignore
├── .gitignore
├── README.md
└── ExportVaultData/             # NOT in git — add your EVD files here
    ├── ExportVaultData.exe       # Main EVD utility
    ├── CreateCredFile/
    │   └── CreateCredFile.exe    # Credential file creator
    ├── Vault.ini                 # Vault connection config
    ├── CreateDB.sql              # MSSQL schema setup
    ├── CreateDB_MSSQL2008.sql    # MSSQL 2008 schema setup
    ├── CAMSSQLImport.cmd         # MSSQL import script
    ├── MasterPolicy.xsl          # Master Policy report template
    └── *.dll                     # Bundled runtime libraries
```

## References

- [CyberArk EVD Installation Guide](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20inst/evd-install.htm)
- [CyberArk EVD System Requirements](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20sysreq/system%20requirements%20-%20evd.htm)
- [scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine) — base Docker image
