# EVD Wine Container

Docker container that runs the CyberArk **Export Vault Data (EVD)** utility under Wine on Linux. The EVD utility exports data from a CyberArk Vault to TXT/CSV files or to an MSSQL database.

## What's inside

- **[scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine)** base image (Ubuntu 22.04 + WineHQ stable)
- **Microsoft Visual C++ Redistributable 2015-2022** (x86 + x64) — installed via winetricks
- **.NET Framework 4.8 Runtime** — installed via winetricks

The EVD application binaries are **not** included in the image. They must be volume-mounted at runtime.

These are the software prerequisites specified in the [CyberArk EVD system requirements](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20sysreq/system%20requirements%20-%20evd.htm).

## Prerequisites

- Docker or Podman
- **Must be built on an amd64 (x86_64) host.** Wine cannot run under QEMU emulation on ARM (Apple Silicon), so building on macOS with `--platform linux/amd64` will fail. Use a Linux amd64 VM or CI runner.
- **CyberArk EVD utility** — the EVD binaries are not included in this repo (vendor software). Obtain the `ExportVaultData` release from your CyberArk representative.

> All `docker` commands below work identically with `podman`.

## Build

No application files are needed at build time. The image only contains the Wine runtime and dependencies.

```bash
docker build --platform linux/amd64 -t evd-wine .
```

> **Note:** The first build takes a long time (30+ minutes). The `.NET 4.8` winetricks installation is the bottleneck — it downloads and installs multiple .NET versions as prerequisites. This is a one-time cost baked into the image. Subsequent rebuilds that only change the entrypoint will be instant due to Docker layer caching.

## Configuration

Before running the EVD utility, you need to:

1. **Obtain the ExportVaultData application** from your CyberArk representative. The directory should contain:

```
ExportVaultData/
├── ExportVaultData.exe
├── CreateCredFile/
│   └── CreateCredFile.exe
├── Vault.ini
├── *.dll
└── ...
```

2. **Edit `Vault.ini`** inside the `ExportVaultData/` directory with your Vault connection details (address, port, etc.)
3. **Create a credential file** using `CreateCredFile.exe` (see below)

## Usage

The ExportVaultData application must be volume-mounted at `/home/wineuser/app/ExportVaultData`. The container will validate that the required files are present and produce a clear error message if they are missing.

Running the container with no arguments prints help:

```bash
docker run --rm evd-wine
```

### Show ExportVaultData usage

```bash
docker run --rm \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine ExportVaultData /?
```

### Create a credential file

Use the `/EntropyFile` flag to encrypt the credential file. Windows DPAPI is not available under Wine, so `/EntropyFile` is the correct protection method for this environment. It generates two files: a `.cred` file and a `.cred.entropy` file. Both are required at runtime.

```bash
mkdir -p creds

docker run --rm --network host \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  -v $(pwd)/creds:/home/wineuser/app/creds \
  evd-wine CreateCredFile creds/user.cred Password \
    /username <username> \
    /password <password> \
    /AppType EVD \
    /EntropyFile
```

This produces:
- `creds/user.cred` — encrypted credential file
- `creds/user.cred.entropy` — entropy key (keep alongside the cred file)

### Run an export

```bash
docker run --rm --network host \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  -v $(pwd)/creds:/home/wineuser/app/creds \
  -v $(pwd)/output:/home/wineuser/app/output \
  evd-wine ExportVaultData \
    '\VaultFile=Vault.ini' \
    '\CredFile=..\..\creds\user.cred' \
    '\LogFile=..\..\output\evd.log' \
    '\Target=FILE' \
    '\safeslist=..\..\output\safes.csv'
```

> **Note:** The EVD utility expects backslash-prefixed parameters (e.g. `\VaultFile=...`). Wrap each argument in single quotes to prevent the shell from interpreting the backslashes. File paths are relative to the ExportVaultData directory inside the Wine environment.

### Available entrypoint commands

| Command | Description |
|---|---|
| `ExportVaultData [args]` | Runs `ExportVaultData.exe` under Wine |
| `CreateCredFile [args]` | Runs `CreateCredFile/CreateCredFile.exe` under Wine |
| `bash` | Drops into a bash shell |
| `<name>.exe [args]` | Runs the named `.exe` from the ExportVaultData directory under Wine |

### Container directory layout

```
/home/wineuser/app/                          <- WORKDIR
├── ExportVaultData/                         <- volume mount (required)
│   ├── ExportVaultData.exe
│   ├── Vault.ini
│   ├── CreateCredFile/
│   │   └── CreateCredFile.exe
│   └── *.dll
├── output/                                  <- volume mount (for export results)
└── creds/                                   <- volume mount (for credential files)
```

## Debugging

### Interactive shell

```bash
docker run --rm -it \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine bash
```

From inside the container you can run commands manually:

```bash
# Run the exe directly
wine /home/wineuser/app/ExportVaultData/ExportVaultData.exe /?

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
docker run --rm -e WINEDEBUG=+all \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine ExportVaultData /?

# Only DLL loading messages
docker run --rm -e WINEDEBUG=+loaddll \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine ExportVaultData /?

# Relay traces (very verbose)
docker run --rm -e WINEDEBUG=+relay \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine ExportVaultData /?
```

### Check installed dependencies

```bash
docker run --rm -it evd-wine bash
winetricks list-installed
# Should show: dotnet48 vcrun2022
```

### Network connectivity

The EVD utility connects to the Vault over TCP (default port 1858). The examples above use `--network host` so the container shares the host's network stack. If you need to use bridge networking instead, ensure the container can route to the Vault and consider passing `--dns` if needed:

```bash
docker run --rm --dns 10.0.0.1 \
  -v /path/to/ExportVaultData:/home/wineuser/app/ExportVaultData \
  evd-wine ExportVaultData <args>
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
└── README.md
```

## References

- [CyberArk EVD Installation Guide](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20inst/evd-install.htm)
- [CyberArk EVD System Requirements](https://docs.cyberark.com/pam-self-hosted/latest/en/content/pas%20sysreq/system%20requirements%20-%20evd.htm)
- [scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine) — base Docker image
