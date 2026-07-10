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

checks = {
    "robot targets exist":
        "robotic_system" in dart
        and "autonomous_ai_agent" in dart
        and '"robotic_system"' in js
        and '"autonomous_ai_agent"' in js,
    "robot subtype taxonomy exists":
        "enum CounterfeitTwinRobotType" in dart
        and "humanoid_robot" in dart
        and "software_robot" in dart
        and "const ROBOT_TYPES" in js,
    "robot hardware incidents exist":
        "counterfeit_robot_hardware" in dart
        and "serial_number_clone" in dart
        and "device_certificate_clone" in js,
    "robot software incidents exist":
        "control_software_clone" in dart
        and "firmware_clone" in js
        and "teleoperation_channel_impersonation" in js,
    "agent identity incidents exist":
        "ai_agent_impersonation" in dart
        and "voice_persona_clone" in js,
    "robot type is sent by client":
        "'robotType': robotType?.value" in dart,
    "robot type is validated by server":
        "Robot veya otonom ajan vakalarinda robotType zorunludur." in js
        and "ROBOT_TYPES" in js,
    "public comparison carries safe robot type":
        'robotType: report.robotType || ""' in js,
    "robot comparison labels exist":
        "Gercek Robot - Sahte Robot" in js
        and "Gercek Otonom Ajan - Sahte Ajan" in js,
    "legacy physical product fallback preserved":
        '"physical_product"' in js
        and "legacyOriginal" in js
        and "legacySuspected" in js,
}

failed = [name for name, ok in checks.items() if not ok]

for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {name}")

if failed:
    print("\nSIR-2A.1 robot taxonomy contract failed:", file=sys.stderr)
    for name in failed:
        print(f"- {name}", file=sys.stderr)
    raise SystemExit(1)

print("\nAll SIR-2A.1 robot taxonomy contract checks passed.")
