FROM ubuntu:18.04

ENV DOCKER_VERSION 27.4.1

RUN apt update && \
    apt install git openjdk-8-jdk wget -y

RUN wget -O docker.tgz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz
