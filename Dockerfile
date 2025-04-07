FROM ubuntu:noble

RUN apt-get update &&\
  apt-get install --yes --no-install-recommends \
  bc \
  curl \
  ca-certificates &&\
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/*

COPY ./wkurwiacz-krzyckiej-9000.sh /usr/local/bin/

VOLUME [ "/var/log/wkurwiacz" ]

ENTRYPOINT ["bash", "wkurwiacz-krzyckiej-9000.sh"]
