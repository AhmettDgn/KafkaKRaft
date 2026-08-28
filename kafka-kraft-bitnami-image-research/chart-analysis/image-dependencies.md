# Image bağımlılık envanteri

## Kapsam ve yöntem

`Chart.yaml`, `values-template.yaml`, ortam values dosyası ve bütün `templates/` dosyaları tarandı. Aşağıdaki envanter chart'ın gerçek render davranışını ifade eder; yalnızca Chart annotation'larına dayanmaz.

## Image envanteri

| Mantıksal bileşen | Varsayılan değer | Değer anahtarı | Ne zaman render edilir? | Doğrudan yerine geçer mi? |
| --- | --- | --- | --- | --- |
| Kafka runtime | `bitnami/kafka:4.0.0-debian-12-r10` | `image.*` | Broker, controller ve `prepare-config`; provisioning açıksa Job'ın üç container'ı | Hayır; Bitnami script/path sözleşmesi var |
| Volume permissions | `bitnami/os-shell:12-debian-12-r51` | `defaultInitContainers.volumePermissions.image.*` | Persistence ve ilgili init container etkinse | Hayır; template `/bin/bash` çağırır |
| External auto-discovery | `bitnami/kubectl:1.33.4-debian-12-r0` | `defaultInitContainers.autoDiscovery.image.*` | `externalAccess.enabled` ve auto-discovery etkinse | Hayır; `kubectl` + bash gerekir |
| JMX exporter | `bitnami/jmx-exporter:1.4.0-debian-12-r0` | `metrics.jmx.image.*` | `metrics.jmx.enabled` ise | Koşullu; JAR adı/komut sözleşmesi doğrulanmalı |

`provisioning.image` anahtarı bu chart sürümünde bulunmamaktadır. Provisioning Job, `include "kafka.image"` kullanır; bu nedenle yalnız `kubectl` imajı override edilerek provisioning Bitnami'den ayrılamaz.

## Bitnami dışı bağımlılık

`Chart.yaml`, `common` bağımlılığını `oci://registry-1.docker.io/bitnamicharts` konumundan ve `2.x.x` sürüm aralığından alır. Bu image bağımlılığı değildir; ancak hedef “Bitnami'den tamamen ayrılmak” ise library chart'ın vendorlama/fork/yerel helper ile değiştirilmesi gerekir. Aksi durumda deploy sırasında Bitnami chart registry'sine tedarik zinciri bağımlılığı devam eder.

## Mevcut değer katmanı

Ana `values-template.yaml` image registry/repository alanlarında kurum placeholder'ları (`__ECR_REGISTRY__`, `__ECR_PREFIX__`) kullanır. Bu, bir registry mirror kullanıldığını gösterir; içerideki imajların kaynağını tek başına kanıtlamaz. Buna karşılık `Chart.yaml` annotation'ları ve template yorumları açıkça Bitnami kaynaklı dört imajı listeler.

## Sonuç

Image repository alanları override edilebilir; fakat bu değer esnekliği runtime uyumluluğu anlamına gelmez. Kritik kabul testi, render edilen manifestte Bitnami image adının olmaması değil, init container, ana process, provisioning ve metrics container'larının seçilen imajın gerçek dosya sistemi/entrypoint sözleşmesiyle çalışmasıdır.
