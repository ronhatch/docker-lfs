vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

status/builder.ok: cleanup.ok
	docker build --target=builder -t ronhatch/lfs-builder . 2>&1 | tee build-logs/builder.log
	touch status/builder.ok

status/cleanup.ok: util-linux.tar.gz | status
	docker build --target=cleanup -t ronhatch/lfs-cleanup . 2>&1 | tee build-logs/cleanup.log
	touch status/cleanup.ok

tarballs/util-linux.tar.gz: util-linux-bld.log | build-logs tarballs
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-util-linux-bld \
	make DESTDIR=/lfs install | tee build-logs/util-linux.log
	docker run --rm -v fakeroot:/lfs -v $(CURDIR)/tarballs:/mnt -w /lfs ubuntu \
	tar czf /mnt/util-linux.tar.gz .
	docker volume rm fakeroot

build-logs:
	mkdir build-logs
status:
	mkdir status
tarballs:
	mkdir tarballs

