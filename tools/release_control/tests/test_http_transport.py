from __future__ import annotations

import json
import unittest

from markakalkan_release.http_transport import (
    ResponseTooLarge,
    StrictHttpsJsonTransport,
    TransportError,
)


class FakeResponse:
    def __init__(self, status=200, payload=None):
        self.status = status
        self._raw = json.dumps(
            {"ok": True} if payload is None else payload
        ).encode("utf-8")

    def read(self, size):
        return self._raw[:size]

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class FakeOpener:
    def __init__(self, response=None):
        self.calls = []
        self.response = response or FakeResponse()

    def open(self, request, timeout):
        self.calls.append((request, timeout))
        return self.response


def make_transport(opener, key="secret", **kwargs):
    return StrictHttpsJsonTransport(
        base_url="https://tenant.example.com",
        expected_host="tenant.example.com",
        api_key_provider=lambda: key,
        opener=opener,
        **kwargs,
    )


class ConstructionTests(unittest.TestCase):
    def test_http_base_url_rejected(self):
        with self.assertRaises(ValueError):
            StrictHttpsJsonTransport(
                base_url="http://tenant.example.com",
                expected_host="tenant.example.com",
                api_key_provider=lambda: "x",
            )

    def test_host_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            StrictHttpsJsonTransport(
                base_url="https://tenant.example.com",
                expected_host="other.example.com",
                api_key_provider=lambda: "x",
            )

    def test_base_url_path_rejected(self):
        with self.assertRaises(ValueError):
            StrictHttpsJsonTransport(
                base_url="https://tenant.example.com/api",
                expected_host="tenant.example.com",
                api_key_provider=lambda: "x",
            )


class RequestContractTests(unittest.TestCase):
    def test_get_exact_request(self):
        opener = FakeOpener(FakeResponse(payload={"id": "abc"}))
        t = make_transport(opener)
        result = t.request("GET", "/api/v1/workflows/abc")
        self.assertEqual(result, {"id": "abc"})
        self.assertEqual(len(opener.calls), 1)
        request, timeout = opener.calls[0]
        self.assertEqual(request.full_url, "https://tenant.example.com/api/v1/workflows/abc")
        self.assertEqual(request.method, "GET")
        self.assertEqual(timeout, 90.0)
        self.assertEqual(request.headers["X-n8n-api-key"], "secret")

    def test_put_json_is_canonical(self):
        opener = FakeOpener()
        t = make_transport(opener)
        t.request(
            "PUT",
            "/api/v1/workflows/abc?publishIfActive=false",
            {"z": 1, "a": 2},
        )
        request, _ = opener.calls[0]
        self.assertEqual(request.data, b'{"a":2,"z":1}')

    def test_method_not_allowlisted_fails_before_open(self):
        opener = FakeOpener()
        t = make_transport(opener)
        with self.assertRaises(ValueError):
            t.request("DELETE", "/api/v1/workflows/abc")
        self.assertEqual(opener.calls, [])

    def test_path_not_allowlisted_fails_before_open(self):
        opener = FakeOpener()
        t = make_transport(opener)
        with self.assertRaises(ValueError):
            t.request("GET", "/api/v1/executions")
        self.assertEqual(opener.calls, [])

    def test_get_body_rejected_before_open(self):
        opener = FakeOpener()
        t = make_transport(opener)
        with self.assertRaises(ValueError):
            t.request("GET", "/api/v1/workflows/abc", {"x": 1})
        self.assertEqual(opener.calls, [])

    def test_invalid_api_key_rejected_before_open(self):
        opener = FakeOpener()
        t = make_transport(opener, key="")
        with self.assertRaises(ValueError):
            t.request("GET", "/api/v1/workflows/abc")
        self.assertEqual(opener.calls, [])


class ResponseTests(unittest.TestCase):
    def test_non_object_json_fails_closed(self):
        opener = FakeOpener(FakeResponse(payload=[]))
        t = make_transport(opener)
        with self.assertRaises(TransportError):
            t.request("GET", "/api/v1/workflows/abc")

    def test_response_size_is_bounded(self):
        class OversizeResponse:
            status = 200
            def read(self, size):
                return b"x" * size
            def __enter__(self):
                return self
            def __exit__(self, exc_type, exc, tb):
                return False

        opener = FakeOpener(OversizeResponse())
        t = make_transport(opener, max_response_bytes=8)
        with self.assertRaises(ResponseTooLarge):
            t.request("GET", "/api/v1/workflows/abc")

    def test_single_attempt_only(self):
        class FailingOpener:
            def __init__(self):
                self.count = 0
            def open(self, request, timeout):
                self.count += 1
                raise RuntimeError("boom")

        opener = FailingOpener()
        t = make_transport(opener)
        with self.assertRaises(RuntimeError):
            t.request("GET", "/api/v1/workflows/abc")
        self.assertEqual(opener.count, 1)


if __name__ == "__main__":
    unittest.main()
