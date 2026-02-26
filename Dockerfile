FROM --platform=linux/amd64 scottyhardy/docker-wine:latest

# The base image provides:
#   - Ubuntu 22.04 with Wine (WineHQ stable), winetricks, xvfb, gosu
#   - An entrypoint that creates a user and initialises Wine at runtime
#
# We set up the Wine prefix with .NET 4.8 and VC++ 2015-2022 at build time
# so the container starts fast. The ExportVaultData application files are
# NOT baked into the image — they must be volume-mounted at runtime to
# /home/wineuser/app/ExportVaultData.

ENV HOME=/home/wineuser
ENV WINEPREFIX=/home/wineuser/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV DISPLAY=:0

# Create the user that will own the Wine prefix
RUN useradd -m -s /bin/bash -u 1010 wineuser

# Initialise Wine prefix as wineuser
USER wineuser
RUN xvfb-run wineboot --init && \
    wineserver --wait

# Install .NET Framework 4.8 via winetricks (pulls in all prerequisites)
RUN xvfb-run winetricks -q dotnet48 && \
    wineserver --wait

# Install Visual C++ 2015-2022 Redistributable (x86 and x64)
RUN xvfb-run winetricks -q vcrun2022 && \
    wineserver --wait

# Create the app directory with mount point for ExportVaultData and default subdirectories
RUN mkdir -p /home/wineuser/app/ExportVaultData /home/wineuser/app/logs /home/wineuser/app/exports /home/wineuser/app/creds && \
    chown -R wineuser:wineuser /home/wineuser/app

WORKDIR /home/wineuser/app

# Use our own lightweight entrypoint instead of the base image's
COPY --chown=wineuser:wineuser entrypoint.sh /home/wineuser/entrypoint.sh
RUN chmod +x /home/wineuser/entrypoint.sh

# Switch to root so entrypoint can fix volume mount ownership, then drop privileges
USER root
ENTRYPOINT ["/home/wineuser/entrypoint.sh"]
