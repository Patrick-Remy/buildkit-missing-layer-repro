FROM alpine:latest

ARG AIRSONIC_VER

RUN mkdir /var/airsonic &&\
  addgroup -g 504 airsonic

COPY entrypoint.sh /entrypoint.sh

USER airsonic
WORKDIR /var/airsonic

ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-Dserver.address=0.0.0.0","-Dserver.port=4040","-Dserver.contextPath=/","-Djava.awt.headless=true","-jar","/var/airsonic/airsonic.war"]

