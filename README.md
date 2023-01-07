# Docker-LFS

Building a Linux from Scratch system (version 11.2) while deviating from the book by doing everything in Docker containers and packaging the results so that it can easily be installed on multiple systems. (Linux from Scratch is available at https://linuxfromscratch.org.)

Primarily a learning project, but also intended to provide a usable minimal Linux system that I can customize.

## Usage

Running the version check script can be done as follows:  
`docker run ronhatch/lfs-prebuild /root/version-check.sh`

Running an interactive shell in the pre-build environment can be done using:  
`docker run -it ronhatch/lfs-prebuild`

## Building

Source tarballs are not included in this Git repository. They can be downloaded by running the following command (must be in the root directory of the repository):  
`docker run -v $(pwd):/mnt ubuntu:22.04 /mnt/scripts/get-packages.sh`

On Windows, unless you are using a Linux-style command line such as WSL, you will need to replace `$(pwd)` as follows:
- In PowerShell, use `${PWD}`
- In Command Shell (Cmd.exe), use `%cd%`

Images were built using:  
`docker build --target=[stage] -t ronhatch/lfs-[stage] . 2>&1 | tee build-logs/[stage].log`
