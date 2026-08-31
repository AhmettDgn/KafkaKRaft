# Kısa sunum / demo notları

Süre: yaklaşık 6 dakika. Amaç: roadmap sorusunu kanıtlarla cevaplamak, başarı ve başarısızlığı ayırmak.

## 1. Problem ve mimari — 1 dakika

KRaft ZooKeeper yerine Kafka içindeki controller quorum ile metadata tutar. Demo üç combined broker/controller kullanır. Orijinal chart'ta dört image ailesi vardır; yalnız broker image'ını değiştirmek init/helper/provisioning/metrics bağımlılıklarını çözmez.

Göster: [mimari](chart-analysis/kraft-architecture.md), [envanter](chart-analysis/image-dependencies.md).

## 2. Alternatif seçimi — 1 dakika

ASF, Confluent, Strimzi, Red Hat, Chainguard ve custom yaklaşımını karşılaştır. Apache 4.0.2 digest'i ve iki mimari manifesti doğrulanmıştır. ASF image'ı seçildi; hiçbir adaya tarama yapmadan “CVE yok” denmedi. Chainguard anonim erişimi 403; bu mimari desteğinin olmadığı anlamına gelmez.

Göster: [tablo](alternatives/image-comparison.md), [manifest](alternatives/manifest-evidence.md), [güvenlik](alternatives/security-evaluation.md).

## 3. Values deneyi — 1 dakika

Repository kökünde, offline; cluster'a hiçbir şey göndermez:

```bash
helm template kafka-lab . -f values-template.yaml -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml | grep -E 'libkafka.sh|KAFKA_CFG_'
helm lint lab/kafka-apache --strict -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
bash scripts/validate.sh
```

İlk komutta Bitnami sözleşmelerinin kalması beklenen negatif bulgudur; grep eşleşmesi deneyin amacıdır. Yeni chart aynı dosyaları kullanmaz. Render geçmesi process/depolama uyumu anlamına gelmez.

## 4. Gerçek deneme ve hata — 2 dakika

[Deploy notlarını](tests/deploy-notes.md), [topic yönetimini](tests/topic-management-test.md), [mesajlaşma kanıtını](tests/producer-consumer-test.md) göster:

- 0.1.0: üç Running pod, üç Bound PVC, quorum, topic ve üç mesaj testi geçti.
- Topic partition sayısı 1'den 3'e artırıldı.
- Restart başarısız: /var/lib/kafka üzerindeki PVC, /var/lib/kafka/data image VOLUME mount'u tarafından örtüldü.
- Mesajların diğer replikalardan okunabilmesi broker'ın disk kalıcılığını kanıtlamaz.
- 0.2.0 exact mount ve koruma kontrolleri eklendi; henüz canlı doğrulanmadı.

Eski cluster üzerinde gösteri amacıyla deploy/restart/smoke --restart çalıştırma. İstenirse yalnız uygun context ve mevcut erişimle salt-okunur durum gösterilebilir:

```bash
export KUBECONFIG=/etc/kafka-kraft/deployer.kubeconfig
kubectl get pods,pvc,sts,svc -n kafka-lab
bash scripts/lab/storage-audit.sh --inspect
```

Legacy düzen mevcutsa audit FAIL beklenir; güvenlik kontrolünün hatayı yakaladığı açıklanmalıdır. Konfigürasyon dosyalarının içeriğini veya tokenları ekranda göstermeyin.

## 5. Sonuç — 1 dakika

“Apache image + bağımsız chart uygulanabilir; salt image override yeterli değildir. Demo mesajlaşması çalıştı, restart kalıcılığı başarısız bulundu ve düzeltildi; düzeltmenin canlı kabulü bekleniyor.”

Sonraki adım veri koruma/yedek veya ayrı güvenli test ortamı kararı, ardından 0.2.0 kalıcılık testi ve gerçek ekran görüntüleridir. Üç pod tek sunucuda fiziksel HA sağlamaz. TLS/SASL/JMX ve production migration kapsam dışıdır.

## Muhtemel mentor soruları

- Neden eski chart'a sadece image yazmadın? prepare-config Bitnami libkafka.sh çağırıyor; Apache imajı bu sözleşmeyi sağlamıyor.
- Helm geçtiyse neden hata çıktı? Helm dosyaları render eder; containerd gerçek mount düzenini veya Kafka veri kalıcılığını test etmez.
- Her alternatif iki mimaride test edildi mi? Hayır; üç adayın manifestleri kontrol edildi, canlı çift mimari testi yapılmadı.
- Çalışma tamam mı? Araştırma/deneme/teknik açıklama mevcut. Gerçek ekran görüntüleri eksik; ideal düzeltilmiş demo kalıcılığı henüz onaylanmadı.
