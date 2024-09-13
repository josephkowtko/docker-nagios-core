# syntax=docker/dockerfile:1
# Use the Latest Ubuntu Image
FROM ubuntu:latest
# Set Initial User, Working Directory, and Environment
USER root
WORKDIR /
ARG DEBIAN_FRONTEND=noninteractive
ARG NAGCOREVER=4.5.4
ARG NAGPLUGVER=2.4.11
ARG NAGADMIN=nagiosadmin
ARG NAGADMINPW=P@55w0rd!
ARG NAGUSER=nagios
ARG NAGCMDUSER=nagcmd
ARG NAGHOSTNAME=nagios-core
ARG APACHEUSER=www-data
# Update and Install Pre-Requisites
RUN apt-get update && apt-get upgrade -y \
    apache2 \
    apache2-utils \
    apt-utils \
    autoconf \
    bc \
    build-essential \
    daemon \
    dc \
    dnsutils \
    gawk \
    gettext \
    gcc \
    iputils-ping \
    libapache2-mod-php \
    libc6 \
    libc6-dev \
    libgd-dev \
    libmcrypt-dev \
    libnet-snmp-perl \
    libperl-dev \
    libssl-dev \
    make \
    net-tools \
    openssl \
    perl \
    php \
    php-gd \
    snmp \
    tini \
    tzdata \
    unzip \
    vim \
    wget
RUN apt clean
# Add Users and Groups
WORKDIR /
RUN useradd -m -s /bin/bash ${NAGUSER}
RUN groupadd ${NAGCMDUSER}
RUN usermod -a -G ${NAGCMDUSER} ${NAGUSER}
RUN usermod -a -G ${NAGCMDUSER} ${APACHEUSER}
# Copy Required Files Into Container
WORKDIR /
COPY ./nagios-${NAGCOREVER}.tar.gz /tmp/nagios-${NAGCOREVER}.tar.gz
COPY ./nagios-plugins-${NAGPLUGVER}.tar.gz /tmp/nagios-plugins-${NAGPLUGVER}.tar.gz
COPY ./entrypoint.sh ./entrypoint.sh
RUN chmod +x /entrypoint.sh
# Extract Nagios and Nagios Plugins
WORKDIR /tmp
RUN tar -zxvf nagios-${NAGCOREVER}.tar.gz
RUN tar -zxvf nagios-plugins-${NAGPLUGVER}.tar.gz
# Compile and Install Nagios Core
WORKDIR /tmp/nagios-${NAGCOREVER}
RUN ./configure --with-nagios-group=${NAGUSER} --with-command-group=${NAGCMDUSER}
RUN make all
RUN make install
RUN make install-commandmode
RUN make install-init
RUN make install-config
RUN /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
# Compile and Install Nagios Plugins
WORKDIR /tmp/nagios-plugins-${NAGPLUGVER}
RUN ./configure --with-nagios-user=${NAGUSER} --with-nagios-group=${NAGUSER} --with-openssl
RUN make
RUN make install
# Create Custom Folder and Set Permissions
WORKDIR /
RUN mkdir /usr/local/nagios/etc/custom
RUN chown -R ${NAGUSER}:${NAGUSER} /usr/local/nagios
RUN chown -R ${NAGUSER}:${NAGCMDUSER} /usr/local/nagios/var/rw
# Configure Apache2 for Nagios
WORKDIR /
RUN ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
RUN a2enmod cgi rewrite
RUN echo "${NAGADMINPW}" | htpasswd -c -i /usr/local/nagios/etc/htpasswd.users ${NAGADMIN}
RUN echo "ServerName ${NAGHOSTNAME}" >> /etc/apache2/apache2.conf
# Clean Up
WORKDIR /
RUN rm -rf /tmp/nagios-${NAGCOREVER}
RUN rm /tmp/nagios-${NAGCOREVER}.tar.gz
RUN rm -rf /tmp/nagios-plugins-${NAGPLUGVER}
RUN rm /tmp/nagios-plugins-${NAGPLUGVER}.tar.gz
RUN truncate -s 0 /usr/local/nagios/var/*.*
RUN rm -rf /usr/local/nagios/var/archive/*
# Start Container Processes
WORKDIR /
EXPOSE 80
ENTRYPOINT ["/usr/bin/tini", "--", "./entrypoint.sh"]
