# Docker-LFS

Building a Linux from Scratch system (version 11.2) while deviating from the book by doing everything in Docker containers and packaging the results so that it can easily be installed on multiple systems. (Linux from Scratch is available at https://linuxfromscratch.org.)

Primarily a learning project, but also intended to provide a usable minimal Linux system that I can customize.

## Usage

Running the version check script can be done as follows:  
`docker run ronhatch/lfs-prebuild /root/version-check.sh`

Running an interactive shell in the pre-build environment can be done using:  
`docker run -it ronhatch/lfs-prebuild`

## Building

On Windows, unless you are using a Linux-style command line such as WSL, you will need to replace `$(pwd)` as follows:
- In PowerShell, use `${PWD}`
- In Command Shell (Cmd.exe), use `%cd%`

Images were built using:  
`docker build --target=[stage] -t ronhatch/lfs-[stage] . 2>&1 | tee build-logs/[stage].log`

Some portions of the build have been automated using Make. Simply run `make` in the root directory of the repository and it will do the rest.  
On Windows if you aren't using WSL, you will need to have gawk, tee, touch, and make installed. If you use Git for Windows, you probably already have its version of gawk, tee, and touch. Try running `[program name] --version` to check. If needed, tee and touch can both be downloaded as part of the Coreutils package from:  
https://sourceforge.net/projects/gnuwin32/files/coreutils/5.3.0/coreutils-5.3.0.exe/download  
Gawk can be downloaded from:  
https://sourceforge.net/projects/gnuwin32/files/gawk/3.1.6-1/gawk-3.1.6-1-setup.exe/download  
Make can be downloaded from:  
https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81.exe/download  
Note that you will need to add [install location]\GnuWin32\bin to your PATH yourself since the installer does not do it automatically.

