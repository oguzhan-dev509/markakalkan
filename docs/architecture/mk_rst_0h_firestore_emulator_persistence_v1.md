# MK-RST-0H Firestore Emulator Persistence Kanıtı V1

## Server-side port sınırı

`persistence_store_port.js`, MK-RST-0G saf planner ile storage adapter'ı ayırır. Port yalnız önceden server tarafında oluşturulmuş `ServerPersistenceFactsV1` kabul eder; client command envelope, authorization claim veya readiness sonucu kabul etmez. Identity çözümleme, permission üretme, readiness değerlendirme, fingerprint veya exact key türetme executor'ın görevi değildir. Port exact permission, resolved tenant, readiness ve subject-target bütünlüğünü yeniden fail-closed kontrol eder; planner kararını değiştirmez.

## Emulator guard

Integration testleri `FIRESTORE_EMULATOR_HOST` bulunmadan veya loopback dışında bir host ile çalışmayı reddeder. Yalnız `demo-markakalkan-rst-0h` project ID kabul edilir ve `GOOGLE_APPLICATION_CREDENTIALS` varsa test durur. Firebase CLI demo project modu, emule edilmeyen servislere erişim girişimlerinin başarısız olacağını doğrular. Testler canlı Firebase projesi veya credential kullanmaz.

## Firestore transaction algoritması

Executor deterministic subject, receipt ve creation-audit referanslarını üretir. Transaction herhangi bir yazımdan önce üç belgeyi `getAll` ile okur. Snapshot'lar tek storage-integrity validator'da karşılaştırılır; ardından mevcut MK-RST-0G planner çalışır. Create dışındaki sonuçlar subject/receipt yazımı yapmaz.

Create planında transaction `create` semantics ile subject, final receipt ve creation audit belgelerini birlikte oluşturur. `set(merge:true)`, update-upsert veya overwrite kullanılmaz. Transaction hata verirse üç yazımın tamamı rollback olur.

## Atomic-collapse receipt politikası

MK-RST-0G planındaki `create_receipt` ve `complete_receipt` mantıksal adımları korunur. Tek atomik Firestore transaction nedeniyle dışarıdan ara `pending` durumu görünmez; receipt doğrudan final `completed` halinde commit edilir. Receipt created/completed zamanı, command/key/fingerprint/document ve deterministic creation audit ID taşır.

## Storage bütünlüğü ve state-machine

- Receipt absent iken subject veya audit present: conflict/no-write.
- Completed receipt yanında subject veya audit eksik: conflict/no-write.
- Tenant, target, subject type/ID, command, exact key, fingerprint veya bağlantı farkı: conflict/no-write.
- Completed ve üç belge tam eşleşiyor: idempotent success/no-write.
- `absent → completed`: yalnız atomik create.
- `completed → completed`: yalnız tam eşleşen replay sonucu; belge güncellenmez.
- Pending: otomatik resume yok, deny/no-write.
- Failed retryable: recompute required.
- Failed non-retryable: deny.
- Conflicted: conflict/no-write.

Lease, pending takeover ve failed auto-retry bilinçli olarak kapsam dışıdır.

## Deterministik creation audit ID

Creation audit ID; audit schema version, receipt ID, persistence document ID, command ID ve `persistence_created` event type değerlerinin mevcut length-prefixed encoding yaklaşımıyla SHA-256 hash'idir. Çıktı 64 lowercase hex karakterdir. Raw tenant ve idempotency key ID'ye girmez. Replay aynı ID'yi bulduğundan ikinci creation audit oluşmaz.

## Concurrency, replay ve conflict kanıtı

Gerçek emulator üzerinde iki paralel Promise ile aynı command çalıştırıldı: sonuçlar tam olarak bir `created` ve bir `idempotent_success`; finalde bir subject, receipt ve creation audit bulundu. Aynı exact key/command ile farklı fingerprint paralel çalıştırıldığında bir `created`, bir `conflict` oluştu ve kazanan payload overwrite edilmedi. Aynı key/farklı subject conflict; farklı tenant/aynı key farklı hashed ID ve ayrı kayıt; yanlış target port seviyesinde deny üretti.

## Atomik başarısızlık kanıtı

Creation audit belgesi önceden sentinel içerikle oluşturuldu. Low-level atomik create aynı transaction içinde üç `create` denedi ve audit precondition nedeniyle transaction başarısız oldu. Son kontrolde subject ve receipt absent, mevcut audit sentinel içeriği değişmemişti. Production koduna failure hook eklenmedi.

## Payload ve zaman politikası

MK-RST-0G limit blocker'ları transaction başlamadan port tarafından reddedilir: title/summary/reason, evidence/related refs, duplicate refs, metadata derinliği/boyutu, provenance alan sayısı ve belge bütçesi. Deny durumunda storage yazımı yoktur. `plannedAt` ve `executedAt` açık test/handler girdisidir; `Date.now()` kullanılmaz.

## Rules server-only sınırı

Gerçek `firestore.rules` içine beş küçük izole match bloğu eklendi. `shared_risk_signals`, `shared_risk_assessments`, `shared_case_candidates`, receipt ve audit koleksiyonlarında client read/create/update/delete tamamen deny'dır. İş mantığı Rules'a taşınmadı. Admin SDK Rules dışındadır ve yalnız gelecekteki yetkili handler trust boundary'sinde kullanılacaktır. Client read ihtiyacı daha sonra callable/read API veya ayrı tenant-read fazıyla değerlendirilmelidir.

## Emulator komutu ve sonuç

Kullanılan komut:

```text
firebase emulators:exec --only firestore --project demo-markakalkan-rst-0h "node functions/shared_risk/persistence/v1/persistence_emulator.test.js && npm test --prefix firestore_rules_tests"
```

Firestore host Firebase CLI tarafından loopback `127.0.0.1:8080` olarak sağlandı. Transaction/concurrency paketi 30 senaryo; mevcut ve yeni Rules paketleri 49/49 test geçti. Rules test dosyaları arası emulator temizleme çakışmasını önlemek için resmi Node runner dosya concurrency değeri 1'dir; transaction concurrency testi kendi içinde gerçek paralel Promise kullanmaya devam eder.

## Kapsam dışı ve MK-RST-0I

Callable/Cloud Function export, canlı Firestore, deploy, istemci entegrasyonu, UI/router, n8n, domain modeli, index ve migration değiştirilmedi. MK-RST-0I, server-side authoritative facts üretim portlarını ve emulator içinde kaynak version/readiness revalidation zincirini kurmalı; callable export ve deploy yine ayrı açık onaylı faz olmalıdır.
