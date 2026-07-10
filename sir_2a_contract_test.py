from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
dart = (
    ROOT
    / "lib/modules/marka_kalkan/sahte_ikiz_sicili/"
      "models/counterfeit_twin_radar_contract.dart"
).read_text(encoding="utf-8")
js = (
    ROOT / "functions/counterfeit_twin/counterfeit_twin_radar.js"
).read_text(encoding="utf-8")

public_start = js.find("transaction.create(publicRef, {")
public_end = js.find("update.counterfeitTwinRecordId", public_start)
public_block = js[public_start:public_end]

checks = {
    "target taxonomy": "tourism_booking_platform" in dart
        and "financial_service" in dart
        and "payment_page" in dart,
    "incident taxonomy": "fake_reservation" in dart
        and "fake_payment_page" in dart
        and "credential_phishing" in dart,
    "financial impact": "CounterfeitTwinFinancialImpact" in dart
        and "disputeStatus" in dart
        and "recoveryStatus" in dart,
    "callable service": "submitCounterfeitTwinReport" in dart,
    "legacy compatibility": "legacyOriginal" in js
        and "legacySuspected" in js
        and '"physical_product"' in js,
    "generalized entities": "originalEntityName" in js
        and "suspectedEntityName" in js,
    "financial validation": "cleanFinancialImpact" in js
        and "Maddi kayip varsa lossAmount zorunludur." in js,
    "public categories": "comparisonLabel" in js
        and "Gercek Platform - Sahte Platform" in js,
    "safe public finance summary": "financialImpactSummary" in public_block
        and "transactionReferenceMasked:" not in public_block
        and "ibanMasked:" not in public_block,
    "collections preserved": '"counterfeit_twin_reports"' in js
        and '"counterfeit_twin_public_comparisons"' in js,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {name}")

if failed:
    print("\nSIR-2A contract test failed:", file=sys.stderr)
    for name in failed:
        print(f"- {name}", file=sys.stderr)
    raise SystemExit(1)

print("\nAll SIR-2A generalized radar contract checks passed.")
