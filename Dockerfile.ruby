# Use official Ruby image
FROM ruby:2.1

####################
# Configure basics #
####################

# Configure timezone server
ENV TZ="Europe/Berlin"
RUN echo "${TZ}" | tee /etc/timezone && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Install missing packages
RUN echo "deb http://ftp.de.debian.org/debian jessie main" >> /etc/apt/sources.list && \
    apt-get update && apt-get install --yes \
    locales

# Set server locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"
RUN locale-gen en_US.UTF-8 && \
    localedef en_US.UTF-8 -i en_US -fUTF-8

# Grab gosu for easy step-down from root
ENV GOSU_VERSION="1.3"
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    arch="$(dpkg --print-architecture)" && \
    set -x && \
    curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$arch" && \
    curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$arch.asc" && \
    gpg --verify /usr/local/bin/gosu.asc && \
    rm /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu

#################################
# Setup epages-docs environment #
#################################

ENV EPAGES_DOCS="/usr/src/epages-docs" \
    EPAGES_USER="epages"

# Add user
RUN groupadd -r ${EPAGES_USER} && useradd -r -g ${EPAGES_USER} ${EPAGES_USER}

# Create the workdir for epages-docs
RUN mkdir -p ${EPAGES_DOCS} && \
    chown -R ${EPAGES_USER}:${EPAGES_USER} /usr
WORKDIR ${EPAGES_DOCS}

# Install gems
COPY Gemfile Gemfile.lock ${EPAGES_DOCS}/
RUN bundle install

# Copy repo to enable running without the mounted volume
COPY . ${EPAGES_DOCS}

# Set mountpoint
VOLUME ${EPAGES_DOCS}

# Open port
EXPOSE 4000

# Add our entrypoint script
COPY _docker/ruby/docker-entrypoint.sh /
RUN chown -R ${EPAGES_USER}:${EPAGES_USER} /docker-entrypoint.sh /usr ${EPAGES_DOCS} && \
    chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

# Set default command
CMD ["rake"]
