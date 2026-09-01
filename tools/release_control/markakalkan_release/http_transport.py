from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable, Mapping, Protocol


class TransportError(RuntimeError):
    pass


class HttpStatusError(TransportError):
    pass


class ResponseTooLarge(TransportError):
    pass


class RedirectRejected(TransportError):
    pass


class _RejectRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RedirectRejected(f"redirect rejected: {code}")


class _Opener(Protocol):
    def open(self, request, timeout: float):
        ...


class StrictHttpsJsonTransport:
    """
    Single-attempt HTTPS JSON transport for n8n workflow operations.

    Security properties:
    - HTTPS only
    - exact host lock
    - workflow API path prefix only
    - GET/PUT/POST only
    - redirect rejection
    - bounded response body
    - one transport attempt per request (no retry loop)
    - API key obtained in-memory from a provider callable
    """

    def __init__(
        self,
        *,
        base_url: str,
        expected_host: str,
        api_key_provider: Callable[[], str],
        timeout_seconds: float = 90.0,
        max_response_bytes: int = 8 * 1024 * 1024,
        opener: _Opener | None = None,
    ) -> None:
        parsed = urllib.parse.urlparse(base_url)
        if parsed.scheme != "https":
            raise ValueError("base_url must use https")
        if parsed.hostname != expected_host:
            raise ValueError("base_url host must equal expected_host")
        if parsed.path not in ("", "/") or parsed.query or parsed.fragment:
            raise ValueError("base_url must not contain path/query/fragment")
        if timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be positive")
        if max_response_bytes <= 0:
            raise ValueError("max_response_bytes must be positive")

        self._base_url = base_url.rstrip("/")
        self._host = expected_host
        self._api_key_provider = api_key_provider
        self._timeout = float(timeout_seconds)
        self._max = int(max_response_bytes)
        self._opener = opener or urllib.request.build_opener(_RejectRedirect())

    @staticmethod
    def _validate_method(method: str) -> str:
        if method not in {"GET", "PUT", "POST"}:
            raise ValueError("method not allowlisted")
        return method

    @staticmethod
    def _validate_path(path: str) -> str:
        if not isinstance(path, str) or not path.startswith("/api/v1/workflows/"):
            raise ValueError("path not allowlisted")
        if "://" in path or "\r" in path or "\n" in path:
            raise ValueError("invalid path")
        return path

    def request(
        self,
        method: str,
        path: str,
        body: Mapping[str, Any] | None = None,
    ) -> Mapping[str, Any]:
        method = self._validate_method(method)
        path = self._validate_path(path)

        if method == "GET" and body is not None:
            raise ValueError("GET body must be None")
        if method in {"PUT", "POST"} and not isinstance(body, Mapping):
            raise ValueError("mutation body must be an object")

        key = self._api_key_provider()
        if not isinstance(key, str) or not key or "\r" in key or "\n" in key:
            raise ValueError("API key provider returned invalid value")

        url = self._base_url + path
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != self._host:
            raise ValueError("resolved URL escaped host lock")

        data = None
        headers = {
            "Accept": "application/json",
            "X-N8N-API-KEY": key,
            "User-Agent": "MarkaKalkan-Release-Control/2",
        }
        if body is not None:
            data = json.dumps(
                body,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                allow_nan=False,
            ).encode("utf-8")
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(
            url=url,
            data=data,
            headers=headers,
            method=method,
        )

        try:
            with self._opener.open(req, timeout=self._timeout) as response:
                status = int(response.status)
                raw = response.read(self._max + 1)
        except RedirectRejected:
            raise
        except urllib.error.HTTPError as error:
            raw = error.read(self._max + 1)
            raise HttpStatusError(
                f"HTTP {error.code}; responseBytes={len(raw)}"
            ) from error
        except urllib.error.URLError as error:
            raise TransportError(
                "URL error: " + type(error.reason).__name__
            ) from error

        if len(raw) > self._max:
            raise ResponseTooLarge(
                f"response exceeds {self._max} bytes"
            )
        if not 200 <= status < 300:
            raise HttpStatusError(f"HTTP {status}")

        try:
            value = json.loads(raw.decode("utf-8"))
        except Exception as error:
            raise TransportError("response is not valid UTF-8 JSON") from error

        if not isinstance(value, Mapping):
            raise TransportError("response JSON must be an object")
        return value
