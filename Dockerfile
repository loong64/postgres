FROM ghcr.io/loong64/debian:trixie-slim

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		dpkg-dev \
		gnupg \
		libnss-wrapper \
		less \
		locales \
		wget \
		xz-utils \
		zstd \
	; \
	echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen; \
	locale-gen; \
	locale -a | grep 'en_US.utf8'; \
	rm -rf /var/lib/apt/lists/*

ENV LANG en_US.utf8

RUN set -ex; \
# pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
#       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
# uid                  PostgreSQL Debian Repository
	key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
	export GNUPGHOME="$(mktemp -d)"; \
	mkdir -p /usr/local/share/keyrings/; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	gpg --batch --export --armor "$key" > /usr/local/share/keyrings/postgres.gpg.asc; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"

ENV PG_MAJOR 14
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ENV PG_VERSION 14.22-1.pgdg13+1

RUN set -ex; \
	\
# see note below about "*.pyc" files
	export PYTHONDONTWRITEBYTECODE=1; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	aptRepo="[ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main $PG_MAJOR"; \
	case "$dpkgArch" in \
		amd64 | arm64 | ppc64el) \
# arches officialy built by upstream
			echo "deb $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
			apt-get update; \
			;; \
		*) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from their published source packages
			echo "deb-src $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
			\
			tempDir="$(mktemp -d)"; \
			cd "$tempDir"; \
			\
# build .deb files from upstream's source packages (which are verified by apt-get)
			nproc="$(nproc)"; \
			export DEB_BUILD_OPTIONS="nocheck parallel=$nproc"; \
			apt-get build-dep -y "postgresql-$PG_MAJOR=$PG_VERSION"; \
			apt-get source --compile "postgresql-$PG_MAJOR=$PG_VERSION"; \
			find . -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} +; \
			\
			cd /; \
			mv "$tempDir" /data; \
			ls -lAFh; \
			;; \
	esac
