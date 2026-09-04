# Apache Kafka + Prometheus JMX agent

Bu dizin yeni bir Kafka dağıtımı üretmez. Resmi `apache/kafka:4.0.2` multi-arch digest'ini temel alır ve yalnız resmi Prometheus JMX Exporter `1.6.0` Java agent jar'ını `/opt/jmx` altına ekler.

Dockerfile uzak asset'i build sırasında SHA256 `a95983fd96e865d2bcdf911cc500e7c82808c27ab9fd226bf96732b6c3d8c46e` ile doğrular. Hash 2026-09-04 tarihinde release asset indirilerek yerelde de doğrulandı.

```bash
docker login ghcr.io
bash images/kafka-jmx/build-and-push.sh
docker buildx imagetools inspect ghcr.io/ahmettdgn/kafka-jmx:4.0.2-jmx-1.6.0
bash images/kafka-jmx/scan-image.sh ghcr.io/ahmettdgn/kafka-jmx@sha256:MANIFEST_DIGEST
```

`build-and-push.sh` amd64 ve arm64 manifesti, provenance ve SBOM ister. Çıktıdaki index digest'i secure values dosyasına yazılmadan deploy yapılmaz. Tag tek başına kullanılmaz. Bu repository GitHub Actions ile image build/push yapmaz.
