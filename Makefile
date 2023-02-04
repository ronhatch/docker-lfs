# NOTE: This isn't going to work under Windows CMD.
# TODO: Fix the entire piping to a log file issue.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

DEST := /install
REPO := ronhatch
WGET_SRC = docker run --rm -v $(CURDIR)/sources:/mnt -w /mnt alpine:3.16 wget

vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

test_pkgs := pre-perl pre-python
test_logs := $(patsubst %, build-logs/%-test.log, $(test_pkgs))

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

# Make sure this is our default target by listing it first...
status/builder.ok:

$(prebuild_img_paths): | build-logs status
$(prebuild_gz_paths): | md5sums tarballs
$(prebuild_gz_paths): tarballs/%.tar.gz: %.ok

image-deps.make: Dockerfile scripts/deps.awk
	gawk -f scripts/deps.awk Dockerfile > image-deps.make
include image-deps.make

status/%.ok:
	$(info Building $* stage because of: $?)
	docker build --target=$* -t $(REPO)/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

build-logs/%-test.log: %.ok
	$(info Running tests for $* stage)
	-docker run --rm $(REPO)/lfs-$* make test | tee build-logs/$*-test.log

tarballs/%.tar.gz: %.ok
	$(info Installing/gzipping $* stage because of: $?)
	docker run --rm -v fakeroot:$(DEST) $(REPO)/lfs-$* \
	/bin/sh /sources/$*-install.sh | tee build-logs/$*-install.log
	docker run --rm -v fakeroot:$(DEST) -w $(DEST) alpine:3.16 \
	find -type f -exec md5sum '{}' \; > md5sums/$*.txt
	docker run --rm -v fakeroot:$(DEST) -v $(CURDIR)/tarballs:/mnt -w $(DEST) alpine:3.16 \
	tar czf /mnt/$*.tar.gz .
	docker volume rm fakeroot

build-logs:
	mkdir build-logs
md5sums:
	mkdir md5sums
status:
	mkdir status
tarballs:
	mkdir tarballs

.PHONY: clean test
clean:
	rm status/*.ok tarballs/*.tar.gz
test: $(test_logs)

