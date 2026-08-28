# Helm render doğrulaması

## Çalıştırılan komutlar

```powershell
& '.\bin\windows-amd64\helm.exe' lint . -f values-template.yaml -f `
  kafka-kraft-bitnami-image-research\helm-values\non-bitnami-values.yaml

& '.\bin\windows-amd64\helm.exe' template kafka . -f values-template.yaml -f `
  kafka-kraft-bitnami-image-research\helm-values\non-bitnami-values.yaml
```

## Sonuç

- `helm lint`: geçti (chart kökünde `values.yaml` bulunmadığı için bilgilendirme mesajı verdi).
- `helm template`: geçti.
- Bu sonuç Kubernetes API doğrulaması veya container çalışma testi değildir.

Render edilen manifestte seçilen Apache imajı görünse bile aşağıdaki Bitnami contract'ları kalır:

```text
/opt/bitnami/scripts/libkafka.sh
/opt/bitnami/kafka/config/server.properties
/opt/bitnami/kafka/logs
KAFKA_CFG_*
/opt/bitnami/scripts/libos.sh
/opt/bitnami/kafka/bin/kafka-broker-api-versions.sh
/opt/bitnami/kafka/bin/kafka-topics.sh
```

Bu ortamda yapılan tarama, override render'ında Bitnami image adı bulunmasa bile söz konusu pattern'lerden 2 eşleşme olduğunu gösterdi. Dolayısıyla “render geçti” sonucu yalnız YAML/template söz dizimi için PASS, runtime uyumluluğu için FAIL/kanıtsızdır.

## Gelecek port için kabul komutları

```powershell
$render = & '.\bin\windows-amd64\helm.exe' template kafka . -f values-template.yaml -f .\ported-values.yaml
$render | Select-String 'image:.*bitnami|/opt/bitnami|libkafka.sh|libos.sh|KAFKA_CFG_' # hiç sonuç dönmemeli
$render | kubectl apply --dry-run=server -f - # cluster erişimi ile
```

Son komutun başarılı olması yalnız API şemasını doğrular; ardından gerçek StatefulSet, topic ve veri yolu testleri gereklidir.
