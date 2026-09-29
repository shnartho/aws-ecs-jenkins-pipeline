FROM jenkins/jenkins:2.568.3-lts-jdk21

USER root

RUN sed -i 's#http://deb.debian.org#https://deb.debian.org#g; s#http://security.debian.org#https://security.debian.org#g' \
      /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null || true; \
    apt-get update; \
    apt-get install -y --no-install-recommends awscli ca-certificates curl git python3 zip; \
    rm -rf /var/lib/apt/lists/*

USER jenkins
