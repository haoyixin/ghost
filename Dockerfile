FROM node:0.10-slim

RUN groupadd user && useradd --create-home --home-dir /home/user -g user user

RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends curl ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN arch="$(dpkg --print-architecture)" \
	&& set -x \
	&& curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$arch" \
	&& curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$arch.asc" \
	&& gpg --verify /usr/local/bin/gosu.asc \
	&& rm /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu

ENV GHOST_SOURCE /usr/src/ghost
WORKDIR $GHOST_SOURCE

ENV GHOST_VERSION 0.7.1

RUN buildDeps=' \
		gcc \
		make \
		python \
		git \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& git clone https://github.com/TryGhost/Ghost.git $GHOST_SOURCE \
	&& npm install -g grunt-cli \
	&& npm install \
	&& grunt init \
	&& grunt prod \
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
	&& npm cache clean \
	&& rm -rf /tmp/npm*

ENV GHOST_CONTENT /var/lib/ghost
RUN mkdir -p "$GHOST_CONTENT" && chown -R user:user "$GHOST_CONTENT"
VOLUME $GHOST_CONTENT

COPY docker-entrypoint.sh /entrypoint.sh

ADD adapter.sh /opt/adapter.sh
ADD config_mysql.js /opt/config_mysql.js
ADD config_sqlite.js /opt/config_sqlite.js
RUN chmod +x /opt/adapter.sh

ENTRYPOINT ["/opt/adapter.sh", "/entrypoint.sh"]
EXPOSE 2368
CMD ["npm", "start", "--production"]
