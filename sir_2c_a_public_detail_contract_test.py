from pathlib import Path

ROOT = Path(__file__).resolve().parent
RADAR = (
    ROOT / "functions/counterfeit_twin/counterfeit_twin_radar.js"
).read_text(encoding="utf-8")
INDEX = (ROOT / "functions/index.js").read_text(encoding="utf-8")
DART = (
    ROOT
    / "lib/modules/marka_kalkan/sahte_ikiz_sicili/models/"
    / "counterfeit_twin_public_contract.dart"
).read_text(encoding="utf-8")


def require(name: str, condition: bool) -> None:
    if not condition:
        raise AssertionError(name)
    print(f"PASS: {name}")


require(
    "three public categories",
    all(
        token in RADAR
        for token in ('"physical"', '"digital"', '"ai_robot"')
    ),
)

require(
    "stable public slug",
    "function buildPublicSlug" in RADAR
    and "slugifyPublicValue" in RADAR
    and "/sahte-ikiz/${slug}" in RADAR,
)

require(
    "public record code",
    "function buildPublicRecordCode" in RADAR
    and "MK-SI-${year}-${suffix}" in RADAR,
)

require(
    "share metadata",
    "buildShareTitle" in RADAR
    and "buildShareDescription" in RADAR
    and "Gerçeği doğrula, sahte ikizi görünür kıl." in RADAR,
)

require(
    "published-only detail",
    'publicationState !== "published"' in RADAR
    and 'publicationState: "published"' in RADAR,
)

require(
    "public detail callable",
    "buildGetPublicCounterfeitTwinComparison" in RADAR
    and 'where("slug", "==", slug)' in RADAR
    and "getPublicCounterfeitTwinComparison" in INDEX,
)

safe_start = RADAR.index("function safePublicComparison")
safe_end = RADAR.index("function cleanReportPayload")
safe_block = RADAR[safe_start:safe_end]

require(
    "safe public whitelist",
    "reporterUid" not in safe_block
    and "reporterEmail" not in safe_block,
)

list_start = RADAR.index(
    "function buildListPublicCounterfeitTwinComparisons"
)
list_end = RADAR.index("module.exports")
list_block = RADAR[list_start:list_end]

require(
    "internal identifiers not spread publicly",
    "...safeData" not in list_block
    and "reportId:" not in list_block,
)

require(
    "dart public category contract",
    "enum CounterfeitTwinPublicCategory" in DART
    and "physical('physical')" in DART
    and "digital('digital')" in DART
    and "aiRobot('ai_robot')" in DART,
)

require(
    "dart detail service",
    "class CounterfeitTwinPublicDetailService" in DART
    and "getPublicCounterfeitTwinComparison" in DART
    and "Future<CounterfeitTwinPublicDetail> getBySlug" in DART,
)

require(
    "internal review note is separated from public summary",
    'const publicSummary = text(' in RADAR
    and 'decision === "published" && !publicSummary' in RADAR
    and "publicSummary: reviewNote" not in RADAR
    and "publicSummary," in RADAR,
)

print()
print("All SIR-2C-A public detail contract checks passed.")
