# Producer / consumer — gerçek sonuçlar

## Kanıt ve durum

Kullanıcının 2026-08-31 Contabo çıktıları, chart 0.1.0 / kaynak 0747716, Apache Kafka 4.0.2. Ajan sunucuda komut çalıştırmadı.

`scripts/lab/smoke-test.sh` tek partition ve RF=3 topic'e acks=all ile üç benzersiz mesaj gönderdi; consumer from-beginning/max-messages=3 ile okudu, script beklenen payload ile tam sıralı eşleşmeyi doğruladı.

```text
Created topic lab-smoke-20260831105749-15898.
Processed a total of 3 messages
PASS: topic creation and exact ordered payload match
Result: PASS; test topic retained: lab-smoke-20260831105749-15898
```

Restart testinin kullandığı ikinci topic'e sonradan yapılan doğrudan okumada:

```text
lab-smoke-20260831110541-17177-event-1
lab-smoke-20260831110541-17177-event-2
lab-smoke-20260831110541-17177-event-3
Processed a total of 3 messages
```

İkinci okuma mevcut mesajların erişilebilir kaldığını kanıtlar; broker 0'ın diskinin korunduğunu kanıtlamaz. Restart testinin bütünü storage kimliği değiştiği için **FAIL** kaldı; yeni mesaj yazma aşamasına ulaşmadı.

## 0.2.0 kalıcılık kabulü — 2026-08-31 21:45 UTC

Kullanıcı `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c` checkout'unda `smoke-test.sh --restart` çalıştırdı. Ajan sunucuda komut çalıştırmadı.

```text
Created topic lab-smoke-20260831214527-8378.
Processed a total of 3 messages
PASS: topic creation and exact ordered payload match
pod "kafka-lab-0" deleted
PASS: all PVCs, mount sources and semantic storage identities unchanged
Processed a total of 3 messages
Processed a total of 4 messages
PASS: replacement pod, unchanged metadata and persistent messages
```

İlk üç mesaj `acks=all` ile yazıldı ve tam sıralı eşleşmeyle okundu. Pod 0 farklı UID ile yeniden oluştuktan sonra aynı üç mesaj tekrar okundu; ardından dördüncü yeni mesaj yazılıp dört mesaj birlikte doğrulandı. Bu kez üç pod'un exact PVC mount'u ile PVC/PV ve semantik cluster/node/directory kimlikleri restart öncesi/sonrası aynıydı. Sonuç: **0.2.0 mesaj ve kalıcılık testi GEÇTİ**.

## Kapsam sınırı

- İlk producer/consumer: **Geçti**.
- Restart sonrası eski mesajların ayrı komutla okunması: **Geçti**, pod-local persistence kanıtı değil.
- Düzeltilmiş 0.2.0 üzerinde restart sonrası eski okuma ve yeni yazı/okuma: **Geçti**.
- Consumer group offset commit/lag=0 için bağımsız kanıt: **Yok**. Bu, önceki taslakta ek kabul kriteriydi; roadmap temel producer/consumer testiyle karıştırılmamalı.
- TLS/SASL client testi: kapsam dışı.

Güncel test scripti unsafe mount'u önce denetler; eski layout'ta topic yaratmadan/pod silmeden durur. Test topic'inin kayıt retention'ı bir saattir; topic nesnesi otomatik silinmez. Bu kontrollü tek-pod replacement testi fiziksel sunucu arızası veya aynı anda üç pod kaybı testi değildir.
