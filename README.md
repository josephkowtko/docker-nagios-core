# Baseline Nagios Core

## Core Components

- Base Image: *ubuntu:latest*
- Nagios Core: *nagios-4.5.9.tar.gz*
- Nagios Plugins: *nagios-plugins-2.4.11.tar.gz*

## Nagios Website Credentials

- User: nagiosadmin
- Password: P@55w0rd!

## Dockerfile

```sh
# syntax=docker/dockerfile:1
# Use the Latest Ubuntu Image
FROM ubuntu:latest
# Set Initial User, Working Directory, and Environment
USER root
WORKDIR /
ARG DEBIAN_FRONTEND=noninteractive
ARG NAGCOREVER=4.5.9
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
RUN chown ${NAGUSER}:${NAGCMDUSER} /usr/local/nagios/var/rw
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
RUN truncate -s 0 /usr/local/nagios/var/*
RUN rm -rf /usr/local/nagios/var/archive/*
# Start Container Processes
WORKDIR /
EXPOSE 80
ENTRYPOINT ["/usr/bin/tini", "--", "./entrypoint.sh"]
```

## Entrypoint Script

```sh
#!/bin/bash

###################
# Start Processes #
###################

## Start Apache2
apachectl -D FOREGROUND &

## Start Nagios Core
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg &

## Give processes time to start

sleep 15

#############################
# Monitor Apache and Nagios #
#############################

## Function to check if a process is running

is_process_running() {
        if pgrep -x "$1" >/dev/null; then
                return 0 # Process is running
        else
                return 1 # Process is not running
        fi
}

## Main function to monitor Apache2 and Nagios processes

monitor_processes() {
        while :
        do
                # Check if Apache2 is running
                if ! is_process_running "apache2"; then
                        echo "Apache2 is not running. Exiting."
                        exit 1
                fi

                # Check if Nagios is running
                if ! is_process_running "nagios"; then
                        echo "Nagios is not running. Exiting."
                        exit 1
                fi

                # Sleep for 5 seconds before checking again
                sleep 5
        done
}

## Starting monitoring processes

monitor_processes
```

## Recommended Employment

This image contains the baseline configuration of Nagios.  I would recommend running the container without any volume mounts, copying the contents of the folder ```/usr/local/nagios``` out of the container, and mounting it as a volume to the container so changes to the configuration will persist container stops and starts or even image rebuilds.  That can be done by using the the docker copy command.  An example of how this would look in ```docker-compose.yaml``` would be:

**NOTE: This assumes a folder named** ```config``` **in the . location.**

```sh
services:
  nagios-core:
    build: .
    container_name: nagios-core
    ports:
      - 80:80
    image: "jtkowtko/nagios-core:latest"
    hostname: nagios-core
    restart: always
    volumes:
      - ./config:/usr/local/nagios
```

## How to Build

To set up to build this image, simply place the following files in a single folder:

- Dockerfile
- entrypoint.sh
- docker-compose.yaml
- nagios-4.5.9.tar.gz
- nagios-plugins-2.4.11.tar.gz

To build the image type the following:

```docker build . -t <image-name>:<tag>```

To run the image in docker using docker compose type the following:

```docker compose up -d```

**NOTE: If you run the container using the volume mount to the host, the files must exist in the folder called** ```config``` **in the same folder that contains all of the contents of the original Nagios Core installation.**
