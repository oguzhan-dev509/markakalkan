from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent

hub = (
    ROOT / "lib/features/dashboard/presentation/corporate_hub_page.dart"
).read_text(encoding="utf-8")
service = (
    ROOT / "lib/features/admin/data/admin_entry_gate_service.dart"
).read_text(encoding="utf-8")
admin_js = (
    ROOT / "functions/admin/brand_application_admin.js"
).read_text(encoding="utf-8")
index_js = (ROOT / "functions/index.js").read_text(encoding="utf-8")
management = (
    ROOT / "lib/features/admin/presentation/management_center_page.dart"
).read_text(encoding="utf-8")

checks = {
    "visible management card removed":
        "id: 'management_center'" not in hub,
    "hidden shield mark exists":
        "Icons.shield_outlined" in hub and "_buildHiddenAdminMark" in hub,
    "two-second hold exists":
        "Duration(seconds: 2)" in hub,
    "three follow-up taps exist":
        "_hiddenTapCount < 3" in hub,
    "client code is not hardcoded":
        "_adminEntryCode" not in hub and "'1234'" not in hub,
    "gate callable client exists":
        "verifyAdminEntryGate" in service,
    "secret manager binding exists":
        'defineSecret("ADMIN_ENTRY_GATE_CODE")' in admin_js,
    "constant-time comparison exists":
        "crypto.timingSafeEqual" in admin_js,
    "super admin required":
        "ROLES.superAdmin" in admin_js,
    "five-attempt lock exists":
        "MAX_ADMIN_ENTRY_FAILURES = 5" in admin_js,
    "callable exported":
        "exports.verifyAdminEntryGate" in index_js,
    "management page retains server access check":
        "_accessService.getMyAccess()" in management
        and "!access.isSuperAdmin" in management,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {name}")

if failed:
    print("\nContract test failed:", file=sys.stderr)
    for name in failed:
        print(f"- {name}", file=sys.stderr)
    raise SystemExit(1)

print("\nAll admin hidden gate contract checks passed.")
