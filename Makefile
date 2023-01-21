vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

status/builder.ok: cleanup.ok
status/cleanup.ok: util-linux.tar.gz | status

status/%.ok:
	docker build --target=$* -t ronhatch/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

tarballs/util-linux.tar.gz: util-linux-bld.log | build-logs tarballs
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-util-linux-bld \
	/bin/sh /sources/util-linux-install.sh | tee build-logs/util-linux-install.log
	docker run --rm -v fakeroot:/lfs -v $(CURDIR)/tarballs:/mnt -w /lfs ubuntu \
	tar czf /mnt/util-linux.tar.gz .
	docker volume rm fakeroot

build-logs:
	mkdir build-logs
status:
	mkdir status
tarballs:
	mkdir tarballs

.PHONY: clean
clean:
	rm status/*.ok tarballs/*.tar.gz

