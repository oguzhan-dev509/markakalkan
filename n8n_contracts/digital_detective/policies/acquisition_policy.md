# Digital Detective acquisition policy

This package defines offline contracts for a manual-seed pilot. It performs no
search, HTTP request, browser automation, callback, or Firestore write.

- Only public HTTPS sources are eligible.
- Login walls and CAPTCHA must never be bypassed.
- robots.txt and platform terms must be evaluated before acquisition.
- At most 3 candidates are allowed per execution.
- Visible text is limited to 50,000 characters and 131,072 UTF-8 bytes per
  source, with a 393,216-byte total budget.
- Personal data must be minimized; credentials, cookies, session IDs, tokens,
  passwords, and API keys are forbidden.
- Automated conclusions are limited to `suspected_signal`; human review is
  mandatory and a conclusive counterfeit judgment is forbidden.
- `network_error` and `http_5xx` may be transient. `http_4xx`, `captcha`,
  `login_required`, and `robots_blocked` must not be retried.
- IDs are deterministic. Canonical URL, source ID, snapshot ID, and finding key
  duplicates are rejected.
- Visible text is normalized with CRLF/CR to LF and Unicode NFC before hashing;
  other whitespace is neither trimmed nor collapsed.
- SHA-256 identity inputs use explicit `source-v1`, `content-v1`, `snapshot-v1`,
  `evidence-fingerprint-v1`, and `finding-v1` domain prefixes separated by `|`.
- `TEST_FIXTURE` data is never production eligible and must be hard-blocked
  before a production callback.

## n8n Cloud portability

Repository modules cannot be required directly from n8n Cloud Code nodes. A
future phase must package or inline the reviewed validator logic in a copied
pilot workflow. This phase intentionally contains no bundler and no workflow
JSON.
