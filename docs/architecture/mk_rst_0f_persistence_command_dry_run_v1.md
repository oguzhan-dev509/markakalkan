# MK-RST-0F Persistence Command Envelope ve Dry-Run Audit V1

## Amaç ve sınır

Bu faz, MK-RST-0E tarafından persistence için hazır olduğu belirlenen ortak risk subject'lerini ileride server-side bir handler'a taşıyacak typed command envelope'ları ve saf dry-run auditor'ları tanımlar. Kod hiçbir Firestore okuması/yazması, ağ çağrısı, auth sorgusu veya command execution yapmaz. `dryRun: false` audit sonucunun anlamını değiştirmez; sonuç yalnız teorik yürütülebilirliği ifade eder.

## Logical storage namespace'leri

V1 yalnız `shared_risk_signals`, `shared_risk_assessments` ve `shared_case_candidates` değerlerini tanır. Bunlar koleksiyon adı değil logical storage hedefidir. Risk Signal, Risk Assessment ve Case Candidate sırasıyla yalnız kendi hedefiyle eşleşebilir; bilinmeyen veya yanlış target fail-closed blocker üretir.

## Authorization modeli

`PersistenceAuthorizationContextV1`, çağıran tarafından sağlanan actor, tenant, opsiyonel brand, authorization zamanı ve kaynağı ile immutable metadata snapshot'ını taşır. Roller ve permission'lar girdiyi mutate etmeden sıralanır ve tekilleştirilir. Roller yetki vermez. Auditor subject türüne göre yalnız `risk_signal.persist`, `risk_assessment.persist` veya `case_candidate.persist` exact permission'ını kabul eder. Geçerlilik, `DateTime.now()` yerine açık `commandRequestedAt` ile sınanır.

## Readiness ve subject fingerprint binding

`ReadinessDecisionBindingV1`, mevcut MK-RST-0E kararını değiştirmeden karar ile `SubjectFingerprintV1` değerini birlikte taşır. Auditor kararı yeniden üretmez veya düzeltmez; allowed durumu, blocker'lar, policy version, subject type/ID, resolved identity, idempotency anahtarı ve zaman sırasını doğrular. Readiness provenance kararın içinde aynen korunur; command provenance bunun yerine geçmez.

Fingerprint, mevcut `crypto` bağımlılığı ile `sha256-canonical-json-v1` algoritmasını kullanır. Map anahtarları sıralanır; sırası semantik olan listeler korunur, ref-set alanları canonical JSON'a göre sıralanır. Böylece map/ref giriş sırası aynı semantik subject'in fingerprint'ini değiştirmez.

## Exact idempotency ve command ID

Risk Signal ve Risk Assessment yalnız `SourceIngestionKeyKind.exactOccurrence` kabul eder. Digital Detective stable recurrence key bu binding'e giremez. Case Candidate ilk persistence binding'i candidate ID, deduplication key, tenant ve logical target'tan kurulur; promotion key ile aynı kavram değildir.

Command ID; contract version, subject type, subject ID, target, canonical persistence idempotency key ve tenant ID'nin MK-RST-0D ile uyumlu length-prefixed encoding'idir. Command zamanı dahil değildir. Aynı semantik talep aynı ID'yi, bileşenlerden herhangi biri değişirse farklı ID'yi üretir; auditor ID'yi yeniden hesaplayarak envelope'u kontrol eder, fakat idempotency binding'i command içinde yeniden türetmez.

## Dry-run audit kararı

Üç typed facade ortak saf çekirdeği kullanır. Issue kodları `command.*`, `authorization.*`, `target.*`, `binding.*`, `fingerprint.*`, `idempotency.*`, `readiness.*` ve `chronology.*` ailelerindedir. Blocker ve warning listeleri deterministik sıralanır. Blocker varsa `executable=false`; yalnız warning varsa `executable=true` kalır. `auditedAt` çağıran tarafından verilir ve command zamanından önce olamaz. Aynı command ile aynı `auditedAt`, byte düzeyinde aynı JSON üretir.

İzinli command üreticileri `risk_orchestration`, `traceability`, `monitoring`, `digital_market_monitoring` ve `digital_detective` ile sınırlıdır. Keyfî UI veya public client modülü fail-closed reddedilir.

## Storage ownership ve gelecekteki callable sınırı

Ortak persistence alanlarının tek sahibi ileride yetkili server-side command handler olacaktır. Flutter istemcisi ortak koleksiyonlara doğrudan yazmayacaktır. Gelecekte Firestore Rules istemci yazımını deny edecek; iş kuralları Rules'a taşınmayacaktır. Callable/handler auth doğrulaması, tenant üyeliği, exact permission, command audit, transaction/idempotency ve immutable provenance kontrollerinin sahibi olacaktır. Bu faz callable veya Rules oluşturmaz.

## Retry ve conflict semantiği

Gelecekteki handler için politika:

- Aynı `commandId`, subject fingerprint, tenant, idempotency key ve target ile daha önce başarıyla tamamlandıysa idempotent success döner.
- Aynı `commandId` farklı payload/fingerprint ile gelirse conflict döner.
- Aynı idempotency key farklı command ID ile aynı semantik persistence talebini temsil ediyorsa mevcut sonuç referanslanır.
- Aynı idempotency key farklı subject veya payload ile gelirse conflict döner.

Bu kurallar bu fazda execute edilmez; transaction ve sonuç kayıt modeli sonraki server-side faza bırakılmıştır.

## Bilinçli kapsam dışı alanlar

Firestore koleksiyonu, Rules/index, Cloud Function/callable, repository/service entegrasyonu, Firebase Auth/custom claims, UI/router, n8n, domain model değişikliği, migration, deploy ve yeni dependency kapsam dışıdır.

## MK-RST-0G önerisi

Bir sonraki faz, bu saf contract ve auditor'ları kullanan server-side handler tasarımını salt-okunur tehdit modeli ve transaction/idempotency kayıt şemasıyla netleştirmelidir. İlk adım deploy veya istemci entegrasyonu değil; callable trust boundary, replay/conflict tablosu, immutable provenance yazım politikası ve Rules deny tasarımının kanıtlanabilir specification'ı olmalıdır.
