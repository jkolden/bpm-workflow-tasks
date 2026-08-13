# Fixing APEX / Fusion Logout ("The logout URL is invalid")

When an APEX app uses Oracle Fusion Authentication (Social Sign-In via IDCS), clicking **Sign Out** may display:

```text
The logout URL is invalid. Please contact your system administrator.
```

This happens because the IDCS confidential app created by the OCI integration wizard does not have the APEX app's URL registered as a valid post-logout redirect. IDCS rejects the redirect and shows the error page instead of returning the user to the login screen.

This also affects the **"Invalid URL" session expiry error** — users cannot sign out and back in to refresh an expired Fusion token if logout is broken.

---

## Quick Click Sheet — TL;DR

Repeat for each APEX app that uses a Fusion auth scheme.

| Step | Go Here | Do This |
|---|---|---|
| **1. Get the redirect URL** | Browser → F12 → Network tab | Check **Preserve log**, click **Sign Out**, find the `userlogout` request to `identity.oraclecloud.com`, copy the full Request URL. |
| **2. Extract the URI** | From the copied URL | Find `post_logout_redirect_uri=` at the end of the URL. URL-decode it — that decoded value is what you register in IDCS. See example below. |
| **3. Open IDCS domain** | OCI Console → Identity & Security → Domains | Select the Fusion identity domain (e.g. `fa-ibzsjb-dev4-oj44w`). |
| **4. Find the app** | Domains → Integrated applications | Open the confidential app (e.g. `APEX_DEV4_INTEGRATION_APP`). |
| **5. Edit OAuth config** | Confidential app → OAuth configuration | Click **Edit OAuth configuration**. |
| **6. Add redirect URL** | Post-logout redirect URLs | Paste the exact URL from Step 2. Multiple URLs are allowed (one per APEX app). |
| **7. Save** | Edit OAuth configuration | Save changes. |
| **8. Test** | APEX app → Sign Out | Should redirect cleanly to the IDCS sign-in page. |

> **The URL must match exactly.** IDCS compares the `post_logout_redirect_uri` APEX sends against the registered list. Trailing slashes, case, and query parameters all matter.

### Step 2 Example

The `userlogout` URL from the Network tab will end with something like:

```text
...&post_logout_redirect_uri=https%3A%2F%2Fg0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com%2Fords%2Fr%2Ffreedemo%2Ffa_integ_ibzsjb_test147%2F
```

URL-decode that value (replace `%3A` → `:`, `%2F` → `/`, etc.) to get:

```text
https://g0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com/ords/r/freedemo/fa_integ_ibzsjb_test147/
```

That decoded URL is what you paste into the IDCS Post-logout redirect URLs field.

> **Tip:** You can paste the encoded URL into the browser address bar and it will decode automatically, or use any URL decoder tool.

---

## Understanding the Problem

### Authentication Flow

```text
User opens APEX app
    ↓
APEX redirects to IDCS (OpenID Connect)
    ↓
User authenticates via Fusion credentials
    ↓
IDCS returns tokens to APEX
    ↓
APEX creates session, stores OAuth tokens
```

### Logout Flow (broken without fix)

```text
User clicks Sign Out
    ↓
APEX clears local session
    ↓
APEX redirects to IDCS /oauth2/v1/userlogout
    with post_logout_redirect_uri=<APEX app URL>
    ↓
IDCS checks: is this URI registered? → NO
    ↓
"The logout URL is invalid"
```

### Logout Flow (after fix)

```text
User clicks Sign Out
    ↓
APEX clears local session
    ↓
APEX redirects to IDCS /oauth2/v1/userlogout
    with post_logout_redirect_uri=<APEX app URL>
    ↓
IDCS checks: is this URI registered? → YES
    ↓
IDCS clears session, redirects to APEX login
    ↓
User sees sign-in page
```

---

## Step-by-Step

### 1. Capture the Redirect URL

The first step is to find out exactly what URL APEX sends to IDCS during logout. Do not guess — capture it.

1. Open the APEX app in the browser
2. Press **F12** to open Developer Tools
3. Go to the **Network** tab
4. Check **Preserve log** (so redirects are not cleared)
5. Click **Sign Out** in the APEX app
6. In the Network log, find the request to `identity.oraclecloud.com` containing `userlogout`
7. Click on it and copy the full **Request URL**

The URL will look like:

```text
https://idcs-<tenant>.identity.oraclecloud.com/oauth2/v1/userlogout
    ?id_token_hint=<long JWT>
    &post_logout_redirect_uri=<URL-encoded APEX app URL>
```

### 2. Extract the post_logout_redirect_uri

Find the `post_logout_redirect_uri=` parameter at the end of the URL and URL-decode it.

Examples of what APEX sends (varies by app configuration):

**Friendly URL format:**

```text
https://g0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com/ords/r/freedemo/fa_integ_ibzsjb_test147/
```

**Legacy f?p= format:**

```text
https://g0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com/ords/f?p=153:1:0::NO:::
```

> **Important:** The format depends on the APEX app's URL configuration. You cannot predict it — capture it from the Network tab.

### 3. Register the URL in IDCS

Navigate to the IDCS confidential app:

```text
OCI Console
→ Identity & Security
→ Domains
→ <Fusion identity domain>  (e.g. fa-ibzsjb-dev4-oj44w)
→ Integrated applications
→ <confidential app>  (e.g. APEX_DEV4_INTEGRATION_APP)
```

Choose the correct confidential app. If multiple exist, match by APEX instance:

| APEX Instance | Confidential App |
|---|---|
| `G0BCA26B76B6699_FREEDEMO` | `APEX_DEV4_INTEGRATION_APP` |
| `G0BCA26B76B6699_GCSATPDEV` | `APEX_FA_DEV4_INTEGRATION_APP` |

In the app's **OAuth configuration** section:

1. Click **Edit OAuth configuration**
2. Find **Post-logout redirect URLs**
3. Add the exact URL from Step 2
4. Save

Multiple URLs can be registered — add one per APEX app that shares this auth scheme.

### 4. Test

Sign out of the APEX app. You should be redirected to the IDCS sign-in page instead of the error page.

---

## Why This Matters for Session Expiry

APEX apps that use Fusion Authentication store OAuth tokens in the APEX session. When the Fusion token expires, REST calls to Fusion fail with:

```text
Invalid URL
```

The fix is for the user to sign out and sign back in, which forces APEX to acquire a fresh token. But if logout is broken, users cannot cycle their session — they are stuck until the APEX session times out on its own or they clear browser cookies.

Fixing the logout redirect is a prerequisite for graceful session expiry handling.

---

## Greenville Configuration

### IDCS Tenant

```text
idcs-60d90cbbee614feda631589e9bbc8d57.identity.oraclecloud.com
```

### Fusion Identity Domain

```text
fa-ibzsjb-dev4-oj44w
```

### Registered Post-Logout Redirect URLs

| App | URL |
|---|---|
| App 147 (Task Notifications) | `https://g0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com/ords/r/freedemo/fa_integ_ibzsjb_test147/` |
| App 153 | `https://g0bca26b76b6699-freedemo.adb.us-ashburn-1.oraclecloudapps.com/ords/f?p=153:1:0::NO:::` |

### Confidential App

```text
APEX_DEV4_INTEGRATION_APP
(for G0BCA26B76B6699_FREEDEMO instance)
```

---

## Troubleshooting

### Still getting "logout URL is invalid" after registering

1. **Exact match** — Copy the `post_logout_redirect_uri` from the Network tab and compare character-by-character with what you registered in IDCS. Trailing slashes and query parameters must match exactly.
2. **Propagation delay** — IDCS may take a minute to apply changes. Try in an incognito window.
3. **Wrong confidential app** — If multiple IDCS apps exist, make sure you edited the one that matches your APEX instance.
4. **Wrong domain** — Make sure you are in the correct Fusion identity domain (e.g. `fa-ibzsjb-dev4-oj44w`, not the root tenant domain).

### APEX auth scheme Post-Logout URL

APEX's Social Sign-In authentication scheme has a **Post-Logout URL** attribute. In testing, APEX sends the correct `post_logout_redirect_uri` automatically without setting this attribute. The IDCS-side registration is what matters.

If logout still fails after registering in IDCS, try setting this attribute in APEX:

```text
Shared Components → Authentication Schemes → <scheme>
→ Post-Logout URL = <same URL registered in IDCS>
```
