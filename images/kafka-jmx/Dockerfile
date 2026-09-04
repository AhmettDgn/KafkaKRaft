# syntax=docker/dockerfile:1.6
FROM docker.io/apache/kafka:4.0.2@sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f
USER root
RUN mkdir -p /opt/jmx && chown 1000:1000 /opt/jmx
ADD --checksum=sha256:a95983fd96e865d2bcdf911cc500e7c82808c27ab9fd226bf96732b6c3d8c46e \
  https://github.com/prometheus/jmx_exporter/releases/download/1.6.0/jmx_prometheus_javaagent-1.6.0.jar \
  /opt/jmx/jmx_prometheus_javaagent.jar
RUN chown 1000:1000 /opt/jmx/jmx_prometheus_javaagent.jar && chmod 0444 /opt/jmx/jmx_prometheus_javaagent.jar
USER 1000
