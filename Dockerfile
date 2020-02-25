FROM arm32v6/alpine:3.11.3

RUN apk update && apk add \
    libgpiod=1.4.1-r0 \
    bash=5.0.11-r1

VOLUME ["/var/log"]
ENTRYPOINT ["/usr/local/bin/piwifimonitor/piwifimonitor.sh"]
CMD [""]

COPY src/ /usr/local/bin/piwifimonitor
RUN chmod 755 /usr/local/bin/piwifimonitor/piwifimonitor.sh
COPY configs/piwifimonitor_config /etc/piwifimonitor_config