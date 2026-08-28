# Deploy doğrulama notları

## Gerçekleşen durum

Bu çalışma alanında `kubectl config current-context` çağrısı, `C:\Users\HP\.kube\config` erişim izni nedeniyle context okuyamadı. Bu nedenle cluster'a deploy yapılmadı; aşağıdaki pod/log çıktıları üretilmedi. Önceki raporlardaki başarılı deploy, quorum veya restart ifadeleri bu ortam tarafından kanıtlanmıyordu ve kaldırılmıştır.

Ek olarak mevcut chart'a yalnız `apache/kafka` image override uygulamak teknik olarak güvenli değildir: `prepare-config` init container'ı ASF imajında olmayan `/opt/bitnami/scripts/libkafka.sh` dosyasını çağırır.

## Port edilmiş chart için test sırası

```bash
helm upgrade --install kafka-kraft ./ported-chart \
  -f ported-values.yaml --namespace kafka --create-namespace --wait --timeout 15m

kubectl get pods,statefulset,svc -n kafka
kubectl get events -n kafka --sort-by=.lastTimestamp
kubectl logs -n kafka kafka-kraft-controller-0 -c prepare-config
kubectl logs -n kafka kafka-kraft-controller-0 -c kafka
```

## Kabul kriterleri

1. Üç controller ve gerekli broker sayısı Ready olur; `ImagePullBackOff`, `CrashLoopBackOff` veya init hatası yoktur.
2. Loglar KRaft quorum kurulumu ve controller leader seçimini gösterir; ZooKeeper yoktur.
3. PVC yeniden bağlandıktan sonra aynı node/directory metadata ile quorum'a katılım gerçekleşir.
4. Tek bir controller/broker pod'u silindikten sonra StatefulSet geri gelir; topic ve producer/consumer testi yeniden geçer.
5. TLS/SASL ve external access kullanılıyorsa bu yollar ayrı test edilir.

## Kanıt formatı

Kullanılacak kanıtlar komut, UTC zaman damgası, chart/image digest'i, Kubernetes sürümü ve hassas bilgi içermeyen ilgili log kesitini içermelidir. Ekran görüntüsü ek kanıt olabilir; metin çıktısının yerine geçmez.
