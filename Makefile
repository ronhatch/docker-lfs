status/builder.ok: status/cleanup.ok
	docker build --target=builder -t ronhatch/lfs-builder . 2>&1 | tee build-logs/builder.log
	touch status/builder.ok

status/cleanup.ok: tarballs/util-linux.tar.gz | status
	docker build --target=cleanup -t ronhatch/lfs-cleanup . 2>&1 | tee build-logs/cleanup.log
	touch status/cleanup.ok

tarballs/util-linux.tar.gz: build-logs/util-linux-bld.log | build-logs tarballs
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-util-linux-bld \
        make DESTDIR=/lfs install | tee build-logs/util-linux.log
	docker run --name util-linux -v fakeroot:/lfs -v tarballs:/mnt -w /lfs \
        ubuntu tar czf /mnt/util-linux.tar.gz .
	docker cp util-linux:/mnt/util-linux.tar.gz tarballs
	docker rm util-linux
	docker volume rm fakeroot tarballs

build-logs:
	mkdir build-logs
status:
	mkdir status
tarballs:
	mkdir tarballs

