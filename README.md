# Docker-LFS

Building a Linux from Scratch system (version 11.2) while deviating from the book by doing everything in Docker containers and packaging the results so that it can easily be installed on multiple systems. (Linux from Scratch is available at https://linuxfromscratch.org.)

Primarily a learning project, but also intended to provide a usable minimal Linux system that I can customize.

## Usage

Running the version check script can be done as follows:
    docker run -v $(pwd)/prebuild-lfs:/lfs ronhatch/prebuild-lfs /lfs/version-check.sh

On Windows, unless you are using a Linux-style command line such as WSL, you will need to replace `$(pwd)` as follows:
- In PowerShell, use `${PWD}`
- In Command Shell (Cmd.exe), use `%cd%`

No additional options are needed when building the image other than setting desired tags. This won't be needed when using the published image from Docker Hub.
