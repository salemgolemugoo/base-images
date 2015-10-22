FROM #{FROM}

# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		libsqlite3-0 \
		libssl1.0.0 \
		libdbus-1-dev \
		libdbus-glib-1-dev \
	&& rm -rf /var/lib/apt/lists/*

# import gpg keys
RUN #{GPG_KEY}

# key 63C7CC90: public key "Simon McVittie <smcv@pseudorandom.co.uk>" imported
RUN gpg --keyserver keyring.debian.org --recv-keys 4DE8FF2A63C7CC90

# key 3372DCFA: public key "Donald Stufft (dstufft) <donald@stufft.io>" imported
RUN gpg --keyserver pgp.mit.edu  --recv-key 6E3CBCE93372DCFA

ENV PYTHON_VERSION #{PYTHON_VERSION}

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 7.1.2

RUN set -x \
	&& buildDeps=' \
		curl \
		gcc \
		libbz2-dev \
		libc6-dev \
		libncurses-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		xz-utils \
		zlib1g-dev \
	' \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& mkdir -p /usr/src/python/pip
	&& curl -SL "https://pypi.python.org/packages/source/p/pip/pip-$PYTHON_PIP_VERSION.tar.gz" -o pip.tar.gz \
	&& curl -SL "https://pypi.python.org/packages/source/p/pip/pip-$PYTHON_PIP_VERSION.tar.gz.asc" -o pip.tar.gz.asc \
	&& gpg --verify pip.tar.gz.asc \
	&& tar -xzC pip --strip-components=1 -f pip.tar.gz \
	&& rm pip.tar.gz* \
	&& cd /usr/src/python/pip \
	&& python3 setup.py install \
	&& cd .. \
	&& rm -rf /usr/src/python/pip \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& cd / \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& rm -rf /usr/src/python

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip3 install --no-cache-dir virtualenv

ENV PYTHON_DBUS_VERSION 1.2.0

# install dbus-python
RUN set -x \
	&& mkdir -p /usr/src/dbus-python \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz" -o dbus-python.tar.gz \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz.asc" -o dbus-python.tar.gz.asc \
	&& gpg --verify dbus-python.tar.gz.asc \
	&& tar -xzC /usr/src/dbus-python --strip-components=1 -f dbus-python.tar.gz \
	&& rm dbus-python.tar.gz* \
	&& cd /usr/src/dbus-python \
	&& PYTHON=python#{PYTHON_BASE_VERSION} ./configure \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /usr/src/dbus-python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s pip3 pip \
	&& ln -s easy_install-#{PYTHON_BASE_VERSION} easy_install \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python-config3 python-config

CMD ["echo","'No CMD command was set in Dockerfile! Details about CMD command could be found in Dockerfile Guide section in our Docs. Here's the link: http://docs.resin.io/#/pages/using/dockerfile.md"]

#{PYTHON_EDISON_MRAA}
