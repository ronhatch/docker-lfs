# Docker-LFS

Building a Linux from Scratch system (version 11.2) while deviating from the book by doing everything in Docker containers and packaging the results so that it can easily be installed on multiple systems. (Linux from Scratch is available at https://linuxfromscratch.org.)

Primarily a learning project, but also intended to provide a usable minimal Linux system that I can customize.

## Usage

Running the version check script can be done as follows:  
`docker run -v $(pwd)/prebuild-lfs:/home/lfs ronhatch/prebuild-lfs /home/lfs/version-check.sh`

Running an interactive shell in the pre-build environment can be done using:  
`docker run -it -v $(pwd)/prebuild-lfs:/home/lfs ronhatch/prebuild-lfs /bin/bash`

On Windows, unless you are using a Linux-style command line such as WSL, you will need to replace `$(pwd)` as follows:
- In PowerShell, use `${PWD}`
- In Command Shell (Cmd.exe), use `%cd%`

## Building

The image was built using:  
`docker build -t ronhatch/prebuild-lfs . 2>&1 | tee image-build.log`
