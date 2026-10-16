"""
Payment service client: a small template for your backend (Python 3.11+, httpx).

Copy it into your service and adapt. It reads two settings from the environment:
    PAYMENT_SERVICE_URL       e.g. https://payment.service.ab0t.com (the URL `authsetup connect payment` printed)
    PAYMENT_SERVICE_API_KEY   your payment key (never sent to a browser, never logged)

Usage in your routes (org_id always from the caller's VALIDATED token):
    payment = PaymentServiceClient()
    plans   = await payment.get_plans(MY_ORG_ID)                                   # your org owns the plans
    session = await payment.create_checkout_session(user.org_id, plan_id, user.email, success_url, cancel_url)
    portal  = await payment.create_portal_session(user.org_id, return_url)
    # redirect the browser to session["url"] / portal["url"]

PaymentServiceError carries the upstream status and detail for YOUR logs; return your own generic
message to the browser (the upstream body names orgs and permissions your customers need not see).
"""

import os
from typing import Any, Dict, Optional

import httpx


class PaymentServiceError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"payment service error ({status_code}): {detail}")


class PaymentServiceClient:
    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None, timeout: float = 15.0):
        self.base_url = (base_url or os.environ.get("PAYMENT_SERVICE_URL", "")).rstrip("/")
        self.api_key = api_key or os.environ.get("PAYMENT_SERVICE_API_KEY", "")
        if not self.base_url or not self.api_key:
            raise RuntimeError("set PAYMENT_SERVICE_URL and PAYMENT_SERVICE_API_KEY (no default URL on purpose)")
        self._http = httpx.AsyncClient(timeout=timeout, headers={"X-API-Key": self.api_key})

    async def close(self) -> None:
        await self._http.aclose()

    async def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        try:
            resp = await self._http.request(method, f"{self.base_url}{path}", **kwargs)
        except (httpx.ConnectError, httpx.TimeoutException) as exc:
            raise PaymentServiceError(503, f"payment unreachable: {type(exc).__name__}") from exc
        if resp.status_code >= 400:
            try:
                body = resp.json()
                detail = body.get("detail") or body.get("message") or body.get("error") or resp.text[:300]
            except ValueError:
                detail = resp.text[:300]
            raise PaymentServiceError(resp.status_code, str(detail))
        return resp.json() if resp.content else {}

    # --- plans (public list; your org owns the plans) --------------------------------------
    async def get_plans(self, plan_owner_org_id: str) -> Dict[str, Any]:
        """{"org_id", "count", "currency", "plans": [{"plan_id", "name", "prices": [...], "default_price"}]}"""
        return await self._request("GET", f"/checkout/{plan_owner_org_id}/plans", params={"include_prices": "true"})

    # --- checkout (customer org) -----------------------------------------------------------
    async def create_checkout_session(self, customer_org_id: str, plan_id: str, customer_email: str,
                                      success_url: str, cancel_url: str) -> Dict[str, Any]:
        """Subscription checkout. Returns {"id", "url", "expires_at", "status", "verification_token"}."""
        return await self._request("POST", f"/checkout/{customer_org_id}/plan/{plan_id}", json={
            "success_url": success_url,   # may contain {CHECKOUT_SESSION_ID}
            "cancel_url": cancel_url,
            "customer_email": customer_email,
        })

    async def create_topup_session(self, customer_org_id: str, amount_dollars: str,
                                   success_url: str, cancel_url: str) -> Dict[str, Any]:
        """Prepaid credit. amount_dollars as a decimal string, e.g. "50.00" (never cents). Needs payment.write."""
        return await self._request("POST", f"/checkout/{customer_org_id}/session", json={
            "amount": amount_dollars,
            "currency": "usd",
            "description": "Account credit",
            "mode": "payment",
            "success_url": success_url,
            "cancel_url": cancel_url,
            "metadata": {"purpose": "topup"},   # org_id, type, plan_id … are set by payment itself
        })

    async def verify_checkout_session(self, session_id: str) -> Dict[str, Any]:
        """Read-only check for your success page; poll subscriptions until active/trialing."""
        return await self._request("GET", f"/checkout/sessions/{session_id}/verify")

    # --- portal and subscriptions (customer org) -------------------------------------------
    async def create_portal_session(self, customer_org_id: str, return_url: str) -> Dict[str, Any]:
        """Returns {"url", "id"}. Needs a Stripe customer: the org must have checked out once."""
        return await self._request("POST", f"/portal/{customer_org_id}/session", json={"return_url": return_url})

    async def get_subscriptions(self, customer_org_id: str, status: Optional[str] = None) -> Dict[str, Any]:
        params = {"status": status} if status else None
        return await self._request("GET", f"/subscriptions/{customer_org_id}", params=params)

    # --- Stripe webhooks, only if you proxy them (otherwise point Stripe at payment) --------
    async def forward_stripe_webhook(self, raw_body: bytes, stripe_signature: str) -> Dict[str, Any]:
        """Forward the RAW body and the Stripe-Signature header unchanged; return payment's answer."""
        return await self._request("POST", "/webhooks/stripe", content=raw_body,
                                   headers={"Stripe-Signature": stripe_signature,
                                            "Content-Type": "application/json"})
