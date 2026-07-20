# MK-RST-0L/R1/R2 internal provisioning callable V1

## Boundary

`provisionInternalTenantBrandPilot` is an authenticated, App Check-enforced,
server-side callable for the canonical internal pilot. Production configuration
remains `dry_run_only` with an empty allowlist. This phase performs no deploy and
no live write.

## Emulator route recovery

The initial 404 was not an export, CommonJS, source, or callable-path defect.
Static `require('./functions')` discovery exposed the exact callable export, and
Functions Emulator debug metadata discovered the `europe-west3` callable. The
failed runner used broad Functions startup and invoked before the target route
was ready while unrelated functions also required local secret resolution.

The minimum recovery is a target-filtered emulator run for
`functions:provisionInternalTenantBrandPilot`, plus project-specific non-secret
configuration in `.env.demo-markakalkan-rst-0l`. Firebase CLI then announces the
target endpoint before `emulators:exec` launches the test command. No fixed sleep
or hand-built callable URL is used.

## Protocol and credential isolation

Firebase CLI normally copies its signed-in credential into the Functions
Emulator child. The R2 launcher instead creates a unique temporary profile and
redirects `HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `XDG_CONFIG_HOME`,
and `CLOUDSDK_CONFIG`. It passes a narrow environment allowlist, removes all
Firebase token, ADC, quota-project and gcloud account overrides, and proves that
`firebase login:list` has no account, configstore has no login file, and the
gcloud config remains empty. Cached emulator binaries are copied into the
temporary profile; the profile and debug logs are deleted after every run.

Only demo project `demo-markakalkan-rst-0l` and loopback Auth, Firestore and
Functions hosts are accepted. A non-emulated Storage sentinel is pinned to an
unused loopback port and must fail locally. The emulator log must contain the
demo-project safety notice and must not contain GAC transfer, production project,
credential or token markers. `.env.demo-markakalkan-rst-0l` contains only
non-secret rollout values; `.env.markakalkan-app` is not loaded into the demo
child.

## App Check acceptance boundary

The production callable options are immutable and tested as region
`europe-west3`, `maxInstances: 1`, and `enforceAppCheck: true`. Firebase Web App
Check's debug provider requires its debug token to be registered in Firebase
Console. A fully local valid debug token therefore cannot be created without
touching the production control plane.

Local acceptance is intentionally split. The real Firebase client SDK callable
protocol proves that unauthenticated, authenticated-without-App-Check, and
authenticated-with-malformed-App-Check requests reach the registered route but
are rejected before the application-handler marker. The same production
application handler is then invoked by an unexported test harness with explicit
verified auth and app identities. This is not a forged App Check token and does
not weaken the production export. A positive valid-App-Check end-to-end proof is
reserved for a later hosted-application, authenticated, zero-write live dry-run.

## Evidence

The isolated real-protocol test proves three negative App Check cases with no
404 and no application-handler invocation. The positive application harness
proves missing, inactive and wrong-role administrator rejection, exact
`internal_tenant_brand.provision` permission, strict request-field and rollout
enforcement, deterministic identifiers, repeated-input stability,
`dry_run_ready`, `transactionCommitted=false`, and ID-based absence in tenant,
brand, membership, receipt and audit collections (`0/0/0/0/0`).

Write-mode atomicity, replay, concurrency, and conflict remain covered by the
existing credential-isolated service-level Firestore Emulator regression. R2
also runs the Monitoring callable, Monitoring application, shared persistence,
all Firestore Rules, legacy brand/corporate contracts, Functions lint/unit tests,
and the complete Flutter suite. No deploy or live operation occurs.

MK-RST-0L-R3 may deploy Rules and this callable only under separate explicit
authorization. Its first live gate must use the hosted application's normal
Firebase Auth plus valid App Check session and must remain `dry_run_only`, empty
allowlist, and zero-write. Write-mode rollout remains a later independent gate.
