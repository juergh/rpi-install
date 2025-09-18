ROOTDIR = $(PWD)

# For reproducible binary installer builds
LC_ALL = C
DATE_EPOCH = '1970-01-01 00:00:00 GMT'
NOW = $(shell date -R)

all: release/rpi-install.tgz

initrd: buildd/initrd.img

# Build the installer initrd tree
buildd/initrdd:
	rm -rf $@/
	mkdir -p $@/
	# Use the git hash as the version
	echo $(NOW) > $@/version
	git rev-parse HEAD >> $@/version
	# Copy the installer init
	cp bin/init bin/init.new $@/
	# Copy binaries and libraries
	rsync --verbose --archive --ignore-existing firmware/ $@/
	# Create the busybox sh link for bin/init
	ln $@/bin/busybox $@/bin/sh

# Build the installer initrd
buildd/initrd.img: buildd/initrdd
	find $< | xargs touch -h -d $(DATE_EPOCH)
	cd $< && find . | sort | cpio --reproducible -H newc -o | gzip -9 > \
		$(ROOTDIR)/$@

buildd/install: buildd/initrd.img
	rm -rf $@/
	mkdir -p $@/
	cp -r kernel/boot/* $@/
	cp buildd/initrd.img $@/
	cp boot/*.txt $@/
	# Create dummy README files required by the firmware
	touch $@/README
	mkdir -p $@/overlays
	touch $@/overlays/README
	# Copy the version
	cp buildd/initrdd/version $@/

release/rpi-install.tgz: buildd/install
	find $< | xargs touch -h -d $(DATE_EPOCH)
	cd buildd && tar --sort=name --owner=0 --group=0 --numeric-owner \
		-czf $(ROOTDIR)/$@ install/

release: clean release/rpi-install.tgz
	# Create a new CHANGELOG entry
	version=$$(head -1 CHANGELOG) ; \
	minor=$${version##*.} ; \
	new_version=$${version%.*}.$$(($${minor} + 1)) ; \
	{ echo "$${new_version}" ; \
	  git log --format='  * %s' "$${version}.." ; \
	  cat CHANGELOG ; } > .changelog
	mv .changelog CHANGELOG

	# Commit and tag the release
	version=$$(head -1 CHANGELOG) ; \
	git commit -s -m "rpi-install $${version}" -- \
		CHANGELOG release/rpi-install.tgz ; \
	git tag -s -m "rpi-install $${version}" "$${version}"

clean:
	rm -rf buildd

.PHONY: release
