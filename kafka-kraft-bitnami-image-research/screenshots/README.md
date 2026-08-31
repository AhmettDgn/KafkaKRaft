# Gerçek ekran görüntüsü teslimi — bekliyor

Kullanıcı terminal çıktıları sağladı; bu klasöre henüz gerçek ekran görüntüsü eklenmedi. Metinlerden üretilmiş görseller gerçek sunucu ekran görüntüsü gibi sunulmayacak.

Roadmap Gün 1 için komut çıktısını da kabul eder; [repo ağacı ve komut](../chart-analysis/kraft-architecture.md) mevcut. Gün 4/5 ayrıca gerçek deploy/test ekran görüntülerini ister.

## Eklenecek kanıtlar

| Önerilen dosya | Görünmesi gereken | Durum |
| --- | --- | --- |
| 01-chart-tree.png | Repo/chart ağacı | İsteğe bağlı; Gün 1 komut kanıtı mevcut |
| 02-pods-pvc-services.png | Namespace, üç pod, üç PVC, StatefulSet ve Service | Eksik |
| 03-quorum-topic.png | Quorum ve topic describe / replication / ISR | Eksik |
| 04-producer-consumer.png | Mesaj gönderme/okuma sonucu | Eksik |
| 05-restart-failure-audit.png | Gerçek eski restart FAIL ve/veya mevcut read-only audit çıktısı | Eksik |
| 06-fixed-restart.png | 0.2.0 başarılı kalıcılık kabulü | Test geçti; gerçek ekran görüntüsü eksik |

Her gerçek görüntü için tarih/saat, komut, source SHA, chart sürümü ve sonucun eski/yeni kuruluma ait olduğunu yazın. Password/token/private key/kubeconfig içeriği gösterilmemeli. Maskelenmiş alanları “maskelendi” diye not edin; test sonucunu değiştirmeyin.

Sırf ekran görüntüsü almak için tekrar pod restart etmeyin veya veri silmeyin. Mevcut başarılı 0.2.0 terminal geçmişinin gerçek görüntüsü kullanılabilir; geçmiş mevcut değilse eski çıktı yeniden çalıştırılmış gibi gösterilmemeli. Salt-okunur güncel durum için `kubectl get pods,pvc,sts,svc -n kafka-lab` ve `bash scripts/lab/storage-audit.sh` kullanılabilir.
