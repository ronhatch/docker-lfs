# NOTE: This isn't going to work under Windows CMD.
# TODO: Fix the entire piping to a log file issue.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

DEST := /install
REPO := ronhatch
WGET_SRC = docker run --rm -v $(CURDIR)/sources:/mnt -w /mnt alpine:3.16 wget

test_pkgs := pre-perl pre-python
test_logs := $(patsubst %, build-logs/%-test.log, $(test_pkgs))
check_pkgs := pre-gettext pre-bison pre-texinfo glibc
check_logs := $(patsubst %, build-logs/%-check.log, $(check_pkgs))
all_tests := $(test_logs) $(check_logs)

prebuild_pkgs := pre-binutils1 pre-gcc1 pre-headers pre-glibc \
    pre-libstdc pre-m4 pre-ncurses pre-bash \
    pre-coreutils pre-diffutils pre-file pre-findutils \
    pre-gawk pre-grep pre-gzip pre-make \
    pre-patch pre-sed pre-tar pre-xz \
    pre-binutils2 pre-gcc2 pre-gettext pre-bison \
    pre-perl pre-python pre-texinfo pre-util-linux
prebuild_imgs := $(addsuffix .ok, $(prebuild_pkgs))
prebuild_img_paths := $(addprefix status/, $(prebuild_imgs))
prebuild_tarballs := $(addsuffix .tar.gz, $(prebuild_pkgs))
prebuild_gz_paths := $(addprefix tarballs/, $(prebuild_tarballs))

main_pkgs := man-pages iana-etc glibc
main_imgs := $(addsuffix .ok, $(main_pkgs))
main_img_paths := $(addprefix status/, $(main_imgs))
main_tarballs := $(addsuffix .tar.gz, $(main_pkgs))
main_gz_paths := $(addprefix packages/, $(main_tarballs))

other_stages := prebuild bundle1 bundle2 bundle3 \
    chroot cleanup builder
other_imgs := $(addsuffix .ok, $(other_stages))
other_img_paths := $(addprefix status/, $(other_imgs))

all_img_paths := $(prebuild_img_paths) $(main_img_paths) $(other_img_paths)
all_gz_paths := $(prebuild_gz_paths) $(main_gz_paths)

# Make sure this is our default target by listing it first...
all: $(main_gz_paths)

$(all_img_paths): | build-logs status
$(prebuild_gz_paths): | md5sums tarballs
$(prebuild_gz_paths): tarballs/%.tar.gz: status/%.ok
$(main_gz_paths): | md5sums packages
$(main_gz_paths): packages/%.tar.gz: status/%.ok

image-deps.make: Dockerfile scripts/deps.awk
	gawk -f scripts/deps.awk Dockerfile > image-deps.make
include image-deps.make

status/%.ok:
	$(info Building $* stage because of: $?)
	docker build --target=$* -t $(REPO)/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

build-logs/%-check.log: status/%.ok
	$(info Running checks for $* stage)
	-docker run --rm $(REPO)/lfs-$* make check 2>&1 | tee build-logs/$*-check.log

build-logs/%-test.log: status/%.ok
	$(info Running tests for $* stage)
	-docker run --rm $(REPO)/lfs-$* make test 2>&1 | tee build-logs/$*-test.log

packages/%.tar.gz: status/%.ok
	$(info Installing/gzipping $* stage because of: $?)
	docker run --rm -v fakeroot:$(DEST) $(REPO)/lfs-$* \
	/bin/sh /sources/$*-install.sh 2>&1 | tee build-logs/$*-install.log
	docker run --rm -v fakeroot:$(DEST) -w $(DEST) alpine:3.16 \
	find -type f -exec md5sum '{}' \; > md5sums/$*.txt
	docker run --rm -v fakeroot:$(DEST) -v $(CURDIR)/packages:/mnt -w $(DEST) alpine:3.16 \
	tar czf /mnt/$*.tar.gz .
	docker volume rm fakeroot

tarballs/%.tar.gz: status/%.ok
	$(info Installing/gzipping $* stage because of: $?)
	docker run --rm -v fakeroot:$(DEST) $(REPO)/lfs-$* \
	/bin/sh /sources/$*-install.sh 2>&1 | tee build-logs/$*-install.log
	docker run --rm -v fakeroot:$(DEST) -w $(DEST) alpine:3.16 \
	find -type f -exec md5sum '{}' \; > md5sums/$*.txt
	docker run --rm -v fakeroot:$(DEST) -v $(CURDIR)/tarballs:/mnt -w $(DEST) alpine:3.16 \
	tar czf /mnt/$*.tar.gz .
	docker volume rm fakeroot

build-logs:
	mkdir build-logs
md5sums:
	mkdir md5sums
packages:
	mkdir packages
status:
	mkdir status
tarballs:
	mkdir tarballs

.PHONY: all check clean test
check: test
clean:
	-rm -f build-logs/*.log md5sums/*.txt packages/*.tar.gz status/*.ok tarballs/*.tar.gz
test: $(all_tests)

