# MK-RST-0G Server Persistence Trust Boundary ve Transaction Planı V1

## Amaç ve güven sınırı

Bu faz ilk gerçek ortak risk persistence handler'ından önce güven sınırını, fiziksel şemayı ve saf transaction planını tanımlar. Firestore/Admin SDK bağlantısı, callable export, Rules/index, runtime, deploy ve migration içermez. Command envelope yetki belgesi değil, doğrulanacak bir taleptir.

| Veri sınıfı | Örnekler | Politika |
|---|---|---|
| Untrusted client input | Subject/envelope, authorization, tenant/brand, readiness, fingerprint, idempotency key, command ID, module, provenance, timestamp, target | Yalnız talep veya tanısal karşılaştırma girdisi; doğrudan persistence gerçeğine dönüşmez. |
| Authoritative server input | Auth UID/service identity, üyelik ve permission kayıtları, identity mapping, kaynak belge ve updateTime/version, server adapter/readiness/fingerprint/key/command ID, server zamanı | Yetkili handler tarafından okunur veya yeniden üretilir. |
| Derived server facts | Resolved tenant/brand, exact permission, canonical subject, target, document/receipt ID ve transaction outcome | Yalnız authoritative input'tan saf ve deterministik olarak türetilir. |

`ServerPersistenceFactsV1` JavaScript karşılığı olan `buildServerPersistenceFactsV1`, yalnız `authoritativeInput` kabul eder. Client claim'leri API'nin dışında kalır. Resolved tenant zorunludur; permission, readiness, module ve payload policy sorunları fail-closed blocker olur. Fingerprint, target, command ID ve storage ID server tarafında yeniden üretilir.

## Tehdit modeli

| # | Tehdit / saldırı örneği | Güven sınırı ve önleyici kontrol | Transaction kontrolü | Audit gereksinimi | Kalan risk |
|---:|---|---|---|---|---|
| 1 | Sahte `authorizationContext` | Client auth yok sayılır; UID/service identity server context'ten gelir. | Exact server permission yoksa deny. | Actor, kaynak ve blocker kodu. | Yetki kaydının yanlış yönetilmesi. |
| 2 | Tenant değiştirme | Tenant üyelik/mapping kaydından çözülür. | Receipt/subject tenant mismatch conflict. | Her iki tenant referansının güvenli özeti. | Yetkili mapping'in bozulması. |
| 3 | Sahte brand | Brand server mapping'inden çözülür. | Cross-brand referanslar doğrulama aşamasında deny. | Resolved brand ve neden kodu. | Eksik brand kapsam politikası. |
| 4 | Rol ile permission yükseltme | Roller yetki vermez; exact permission kaydı gerekir. | Permission blocker ile no-write. | Actor ve eksik permission kodu. | Permission deposu kompromisi. |
| 5 | Sahte allowed readiness | Client kararı tanısaldır; server yeniden değerlendirir. | Server readiness denied ise deny. | Policy version ve blocker'lar. | Policy uygulama hatası. |
| 6 | Sahte fingerprint | Server canonical subject'ten SHA-256 hesaplar. | Receipt fingerprint mismatch conflict. | Client/server mismatch olayı. | Canonicalization bug'ı. |
| 7 | Stable recurrence key'i exact gösterme | Binding purpose subject türüne göre allowlist'tedir. | Yanlış purpose facts üretiminde reddedilir. | Key'in raw olmayan hash'i ve kod. | Kaynak adapter'ın yanlış sınıflaması. |
| 8 | Aynı command replay | Deterministik receipt ID ve integrity karşılaştırması. | Tam eşleşmede idempotent success/no subject write. | Replay audit event'i. | Audit hacmi. |
| 9 | Aynı command ID, farklı payload | Command ve fingerprint server üretilir. | Fingerprint/command mismatch conflict. | Conflict alan kodları. | Hash çarpışması teorik riski. |
| 10 | Aynı key, farklı subject | Exact key, subject ID/type ile receipt bütünlüğü karşılaştırılır. | Conflict. | Key hash ve subject referansları. | Yetkili kaynakta kimlik hatası. |
| 11 | Cross-tenant ref enjeksiyonu | Referans tenantları handler tarafından kaynaklardan doğrulanır. | Tenant değişimi conflict/security deny. | Enjekte edilen ref'in güvenli özeti. | Eski kayıtlarda tenant bilgisinin eksikliği. |
| 12 | Eski readiness kullanma | Client readiness kabul edilmez; source version bağlanır. | Version değişmişse recompute required. | Eski/yeni version özeti. | Version sağlamayan kaynaklar. |
| 13 | TOCTOU | Transaction içinde source updateTime/version yeniden okunur. | Eşleşme yoksa no-write/recompute. | Okunan authoritative version. | Çoklu kaynak atomikliği. |
| 14 | Bilinmeyen module | Açık source allowlist. | Deny. | `source.module_unsupported`. | Yeni modül için kontrollü sürümleme ihtiyacı. |
| 15 | Schema downgrade | Exact schema/policy/contract version allowlist'i. | Unsupported version deny/recompute. | Gelen ve desteklenen version. | Eski client uyumluluğu. |
| 16 | Timestamp spoofing | Server timestamp authoritative; client zamanı yalnız tanısal. | Chronology server zamanlarıyla doğrulanır. | Client/server zamanı ayrımı. | Saat kayması; server clock izleme gerekir. |
| 17 | Provenance silme/değiştirme | Provenance kaynak belge ve server adapter'dan snapshot edilir. | Eksik provenance facts üretiminde reddedilir. | Immutable provenance summary/link. | Kaynak provenance kalitesi. |
| 18 | Aşırı payload/metadata | Boyut, metin, ref, derinlik ve alan sınırları. | Blocker ve no-write. | Yalnız ölçü/kod; hassas payload yok. | Tahmini JSON boyutu Firestore encoding ile birebir değildir. |
| 19 | Duplicate ref şişirme | Duplicate evidence/related refs reddedilir. | Payload blocker. | Duplicate türü ve adet. | Diğer liste türleri için gelecek policy. |
| 20 | Doğrudan client Firestore yazımı | Gelecekte client create/update/delete deny. | Yalnız Admin SDK handler transaction'ı. | Denied Rules telemetry mümkünse. | Yanlış deploy edilmiş Rules. |
| 21 | Kısmi transaction | Subject, receipt completion ve audit aynı transaction sınırında. | Tümü commit veya hiçbiri. | Transaction correlation ID. | Firestore dışı yan etkiler kapsam dışı. |
| 22 | Eş zamanlı aynı talep | Aynı deterministic receipt document okunur. | Bir create; diğeri retry/idempotent sonuç. | Her attempt için event. | Yüksek contention. |
| 23 | Eş zamanlı aynı key farklı payload | Aynı receipt ID üzerinde integrity karşılaştırması. | Bir kazanan; diğeri conflict. | Conflict event'i. | İşletimsel inceleme yükü. |
| 24 | Audit kaydının yazımdan kopması | Audit operation subject/receipt ile aynı plan ve transaction'da. | Create plan dört operation'ı birlikte içerir. | Creation audit link immutable. | Audit koleksiyonu limitleri. |
| 25 | Hatalı retry ile duplicate | Receipt ID ve integrity alanları retry öncesi okunur. | Completed eşleşme idempotent; failed retry revalidation ister. | Retry count/outcome event'i. | Sürekli retry kötüye kullanımı için rate limit gerekir. |

## Fiziksel storage şeması

Repo snake_case koleksiyon geleneğiyle uyumlu V1 koleksiyonları:

- `shared_risk_signals`
- `shared_risk_assessments`
- `shared_case_candidates`
- `shared_risk_persistence_receipts`
- `shared_risk_persistence_audit_events`

Subject storage contract; tenant/brand, subject type/ID ve contract version, canonical payload, fingerprint/algorithm, source module, exact idempotency key, command ID, readiness policy, persisted actor ve server timestamp placeholder, immutable provenance, source version/updateTime ve schema version taşır.

Receipt; receipt/document kimlikleri, tenant/target, subject, command/key/fingerprint bütünlüğü, outcome ve zamanlar ile source version ve provenance summary taşır. Audit event; actor/service, command/subject/target, event/outcome, blocker/warning kodları, raw key yerine SHA-256 key hash'i, fingerprint, server zamanları, correlation ve immutable metadata taşır. IP/device varsayılan olarak saklanmaz; ancak ayrı KVKK politikası ve veri minimizasyon kararıyla eklenebilir.

## Document ID politikası

`sha256-length-prefixed-v1`, UTF-8 byte uzunluklu encoding kullanır. Persistence ID girdisi storage schema version + tenant + logical target + exact canonical key'dir. Receipt ID ayrı sürümlü prefix ile persistence ID'den SHA-256 üretilir. Çıktı 64 küçük harf hex karakterdir; raw tenant/key belge yoluna sızmaz. Candidate için initial persistence binding kullanılır; promotion key reddedilir.

## Transaction algoritması ve replay matrisi

| Receipt/source durumu | Bütünlük | Sonuç | Logical operations |
|---|---|---|---|
| Absent, source mevcut/güncel | Facts geçerli | `create` | create subject + receipt, complete receipt, append audit |
| Completed | Tüm alanlar aynı | `idempotent_success` | no subject write + append attempt audit |
| Completed/pending | Herhangi bir integrity farkı | `conflict` | no write + append audit |
| Pending | Tam aynı | `deny` | no write; kontrollü resume ayrı handler fazına bırakılır |
| Failed retryable | Tam aynı | `recompute_required` | no write; permission/readiness/source yeniden değerlendirilir |
| Failed non-retryable | Tam aynı | `deny` | no write + audit |
| Conflicted | — | `conflict` | no write + audit |
| Source version değişmiş/bilinmiyor | — | `recompute_required` | no write + audit |
| Source silinmiş | — | `deny` | no write + audit |
| Tenant/target/subject/key/command/fingerprint farkı | — | `conflict` | no write + audit |

Planner yalnız logical operation üretir; hiçbir operation'ı yürütmez. Completed receipt overwrite edilmez. Audit append'in gelecekte subject/receipt değişiklikleriyle aynı Firestore transaction'ında yapılması zorunludur.

## TOCTOU ve source version

Handler adapter/readiness sonrasında ve write transaction'ı içinde authoritative source document'i yeniden okumalıdır. Kaynak yoksa deny; updateTime/version değişmişse recompute; tenant değişmişse security conflict; bilgi desteklenmiyorsa açık `source.version_unavailable` sonucu üretilir. Client source version beyanı kullanılmaz.

## Server-side revalidation matrisi

| Alan | Client taşıyabilir | Güvenilir | Server işlemi |
|---|---:|---:|---|
| Subject payload | Evet | Hayır | Kaynak belgeden yeniden adapter çalıştır veya canonical sonuçla karşılaştır. |
| Actor UID/type | Hayır/tanısal | Hayır | Auth context veya doğrulanmış service identity'den üret. |
| Tenant/brand | Evet | Hayır | Membership ve identity mapping'den çöz. |
| Roles/permissions | Evet | Hayır | Server permission kaydından exact permission hesapla. |
| Readiness | Evet | Hayır | Server adapter/identity/readiness zincirini yeniden çalıştır. |
| Fingerprint | Evet | Hayır | Canonical server subject'ten yeniden hesapla. |
| Idempotency key | Evet | Hayır | Authoritative source kimliklerinden exact key üret. |
| Command ID | Evet | Hayır | Server facts'tan yeniden hesapla ve gerekiyorsa client değeriyle karşılaştır. |
| Target | Evet | Hayır | Subject type allowlist'inden türet. |
| Module/provenance | Evet | Hayır | Kaynak route/belge ve server adapter'dan üret. |
| Timestamp | Evet | Hayır | Server timestamp kullan; client zamanını yalnız tanısal sakla. |

## Immutable provenance

İlk yazımdan sonra tenant, subject type/ID, source module/ref, exact key, command ID, initial fingerprint/algorithm, execution/task/finding kimlikleri, source timestamps, persistedAt/by ve creation audit link değiştirilemez. Yeni bilgi mevcut belgeyi yeniden yazmak yerine yeni version, derived record, status transition veya linked audit event olarak eklenir.

## Rules trust boundary

Gelecekte ortak koleksiyonlarda client create/update/delete deny; read için auth, tenant membership ve gerekiyorsa brand scope zorunlu olacaktır. Kamu erişimi yoktur. Admin SDK yalnız yetkili handler'da kullanılır. Rules iş kurallarını taşımaz; erişim ve tenant izolasyonuyla sınırlı kalır. Küçük izole match blokları kullanılır, 200 KiB hedefinin altında kalınır ve mevcut canlı Rules büyük refactor edilmez. Bu faz Rules dosyasını değiştirmez.

## Payload limitleri

Policy: title 300, summary 4.000, her reason 1.000 karakter; en çok 100 reason, 200 related ref, 200 evidence ref; metadata derinliği 6, tahmini metadata 32 KiB, provenance 64 top-level alan ve canonical payload 512 KiB. Duplicate evidence/related ref reddedilir. 512 KiB bütçe Firestore'un belge limitine güvenlik payı bırakır; runtime handler gerçek serialized boyutu ayrıca ölçmelidir.

## Bilinçli kapsam dışı ve MK-RST-0H

Bu faz Firestore, Admin SDK, callable export, Auth/custom claims sorgusu, Rules/index, UI/router, n8n, domain model, dependency, migration veya deploy içermez. MK-RST-0H önce transaction handler'ının port/interface katmanını, emulator tabanlı atomiklik ve concurrency testlerini, receipt state-machine geçişlerini ve Rules deny test planını geliştirmelidir; canlı export/deploy ayrı onaylı faz olmalıdır.
