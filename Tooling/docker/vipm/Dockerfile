FROM nationalinstruments/labview:2025q3patch1-linux

RUN apt-get update \
  && apt-get install -y wget \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/jki/vipm /etc/jki \
    && touch /usr/local/jki/vipm/Settings.ini /etc/jki/jki.conf

ARG VIPM_DEB_URL="https://packages.jki.net/vipm/preview/vipm_latest_preview_amd64.deb"
RUN wget -O /tmp/vipm.deb "$VIPM_DEB_URL" \
    && dpkg -i /tmp/vipm.deb \
    && rm /tmp/vipm.deb

RUN vipm help

CMD [ "bash" ]
