ARG BUILD_FROM
FROM $BUILD_FROM

ENV LANG C.UTF-8

# Install system dependencies and mopidy via pip
# Note: mopidy-spotify and Mopidy-GMusic are removed because they depend on
# libspotify (deprecated by Spotify) and Google Play Music (shut down).
RUN set -ex \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
	build-essential \
        curl \
        gcc \
	gstreamer1.0-alsa \
	gstreamer1.0-plugins-good \
	gstreamer1.0-libav \
	libz-dev \
	jq \
	python3-dev \
	python3-pip \
 && pip3 install --break-system-packages -U six \
 && pip3 install --break-system-packages \
	mopidy \
	mopidy-local-sqlite \
	Mopidy-Moped \
	Mopidy-Iris \
 && apt-get purge --auto-remove -y \
        curl \
        gcc \
	build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

COPY mopidy.conf /var/lib/mopidy/.config/mopidy/mopidy.conf

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 6600 6680
CMD [ "/run.sh" ]
