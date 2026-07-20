# MK-RST-0K Canonical Tenant–Brand–Membership Core V1

## Karar

Legacy kurumsal erişim `brands/{applicantUid}` belgesini doğrudan Firebase Auth
UID'siyle okur. Başvuru onayı aynı belgeyi oluşturur; ürün, üretim ve Dijital
Dedektif alt koleksiyonları da bu kökü kullanır. Bu nedenle farklı belge kimliği
semantiğine sahip canonical markalar mevcut `brands` koleksiyonuna eklenmez.

Collection strategy:

- `tenants`: canonical tenant gerçeği
- `canonical_brands`: tenant'a bağlı canonical marka gerçeği
- `tenant_memberships`: canonical kullanıcı–tenant yetkisi
- `tenant_brand_provisioning_receipts`: tamamlanmış işlem/idempotency kanıtı
- `tenant_brand_provisioning_audit_events`: immutable creation audit

Bu ayrım legacy marka gerçeğini değiştirmez ve internal markaları mevcut
corporate access, public UI veya Radar sorgularına sokmaz. `functions/index.js`
export'u yoktur; V1 yalnız emulator üzerinde server-side çekirdektir.

## Sözleşmeler

Tenant `canonical-tenant-v1`; `internal|customer` türleri için tasarlanmıştır.
Bu faz yalnız `internal`, `active`, `private` üretir. Marka
`canonical-brand-v1`; zorunlu `tenantId`, `internal`, `private` ve `unverified`
değerleriyle oluşturulur. Yasal şirket, vergi, telefon, adres, tescil, ödeme veya
abonelik alanı yoktur.

Membership `tenant-membership-v1`; deterministik ID ile tek `owner` üretir.
Exact permission `internal_tenant_brand.provision` yalnız server policy
tarafından aktif `super_admin` için türetilir. İstemci role, permission, UID,
tenant ID veya brand ID gönderemez.

## Provisioning ve idempotency

V1 request yalnız `pilotCode`, `dryRun` ve opsiyonel `correlationId` kabul eder.
Allowlist yalnız `MK-RST-0J-INTERNAL-001` değeridir; tenant ve marka adları
server policy içindedir.

Kimlikler mevcut `sha256-length-prefixed-v1` yardımcılarıyla; payload
fingerprint'leri sıralı canonical JSON üzerinden SHA-256 ile üretilir. Raw UID
ve pilot code belge ID'lerinde görünmez. Tek Firestore transaction tüm mevcut
durumu okur ve yalnız tamamen boş durumda tenant, marka, membership, completed
receipt ve audit olmak üzere beş `create` gerçekleştirir. Tam set replay'i
`idempotent_success`; eksik/orphan veya fingerprint sapması `conflict` olur.
Dry-run aynı authorization ve state kontrollerini çalıştırır, write yapmaz.

## Rules ve legacy uyumluluğu

Beş canonical koleksiyon client read/write için tamamen kapalıdır. İş kuralları
Rules'a taşınmamıştır. Legacy `brandApplications`, `brands/{applicantUid}` ve
mevcut alt koleksiyon Rules blokları değiştirilmemiştir. Yeni collection query
ve index gereksinimi yoktur.

## Güvenlik ve yaşam döngüsü

Provisioning yalnız loopback Firestore Emulator, project
`demo-markakalkan-rst-0k` ve production credential bulunmayan süreçte test
edilir. Canlı callable export'u, deploy, canlı tenant/brand, Monitoring veya
shared-risk write yapılmaz. Internal kayıt private ve unverified kalır; public
yayın, e-posta, billing, n8n, Monitoring ve risk yan etkisi yoktur.

MK-RST-0J'ye dönüşte ayrı faz önce bu çekirdeği kontrollü callable/export ve
canlı rollout güvenlik incelemesine tabi tutmalı; ardından internal kaynak
provisioning ve Monitoring pilot event/signal aşaması ayrıca yetkilendirilmelidir.
