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

## Kapsam sınırı

- İlk producer/consumer: **Geçti**.
- Restart sonrası eski mesajların ayrı komutla okunması: **Geçti**, pod-local persistence kanıtı değil.
- Düzeltilmiş 0.2.0 üzerinde restart sonrası yeni yazı/okuma: **Çalıştırılmadı**.
- Consumer group offset commit/lag=0 için bağımsız kanıt: **Yok**. Bu, önceki taslakta ek kabul kriteriydi; roadmap temel producer/consumer testiyle karıştırılmamalı.
- TLS/SASL client testi: kapsam dışı.

Güncel test scripti unsafe mount'u önce denetler; eski layout'ta topic yaratmadan/pod silmeden durur. Mevcut cluster üzerinde yeni restart denemesi yapılmamalıdır. Mesaj retention'ı bir saattir; topic nesnesi otomatik silinmez.
