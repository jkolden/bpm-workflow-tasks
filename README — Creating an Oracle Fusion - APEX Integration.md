# Creating an Oracle Fusion / APEX Integration

This document describes the process for connecting an Oracle APEX environment to one or more Oracle Fusion Applications environments using OCI Database Tools.

It also documents the troubleshooting steps used when the integration wizard returned:

```text
ORA-18714: Login timeout specified by DataSource.setLoginTimeout(int)
or by the oracle.jdbc.loginTimeout property has expired.
```

## Quick Click Sheet — TL;DR

Use this checklist when creating a new APEX/Fusion integration. The detailed sections below explain each step and provide troubleshooting guidance.

| Step | Go Here | Do This |
|---|---|---|
| **1. Database** | OCI → Autonomous AI Database | Identify the APEX database and compartment. |
| **2. Vault** | Identity & Security → Key Management → Vault | Select an existing Vault **or create one**. |
| **3. Master Key** | Vault → Master encryption keys | Select/create a key using **HSM → AES → 256-bit**. |
| **4. DB Connection** | Developer Services → Database Tools → Connections → Create connection | Select **Oracle Autonomous AI Database** and the target database. |
| **5. Username** | Create Connection | Enter **ADMIN**. |
| **6. Password Secret** | Create Connection → Create password secret | Select the Vault + key and enter the target database's **ADMIN password**. If a valid secret already exists, select it instead. |
| **7. Wallet** | Create Connection → SSL details | Select **Oracle auto-login wallet**. |
| **8. Wallet Secret** | SSL details → Create wallet content secret | Choose **Retrieve regional wallet from Autonomous AI Database** and select the Vault + key. |
| **9. Create** | Create Connection | Create the connection and wait for **Active**. |
| **10. TEST IT** | Connection → SQL worksheet | Run `SELECT SYSDATE, USER FROM DUAL;` — it must execute successfully and return **ADMIN**. |
| **11. Fusion** | Connection → Actions → Integrate APEX with Fusion Applications | Select the desired Fusion environment and click **Integrate**. |
| **12. Verify in OCI** | Connection → Credentials | Look for `APEX$FA_<FUSION-ENV>_CRED` in **Enabled** state. |
| **13. Verify in APEX** | APEX → Create App → Create Fusion Integration | Confirm the Fusion environment appears in the **Fusion Instance Name** dropdown. |

> **STOP at Step 10 if SQL Worksheet does not work.** Do not troubleshoot the Fusion integration until the Database Tools connection can successfully execute SQL as `ADMIN`.

> **Existing resources may be reused.** You do not need to create a new Vault, encryption key, or password secret if appropriate working resources already exist and IAM permits access. When troubleshooting, do not modify, rotate, replace, or delete existing resources that may already be in use.

### What Success Looks Like

```text
Autonomous Database available
        ↓
Password secret valid
        ↓
SSO wallet secret valid
        ↓
Database Tools connection Active
        ↓
SQL Worksheet returns ADMIN
        ↓
Integrate APEX with Fusion Applications
        ↓
APEX$FA_<FUSION-ENV>_CRED is Enabled
        ↓
Fusion environment appears in APEX
```

---

## Overview

The integration path is:

```text
Oracle APEX
   ↓
Autonomous Database
   ↓
OCI Database Tools Connection
   ↓
OCI Fusion Applications Integration
   ↓
Fusion Environment
```

The Database Tools connection must be working before the **Integrate APEX with Fusion Applications** wizard can succeed.

---

## 1. Identify the Autonomous Database Behind APEX

In OCI, navigate to:

```text
Oracle Database
→ Autonomous Database
```

Open the database associated with the APEX environment.

Examples used during the Greenville setup:

```text
APEX database: GCSAPEX
Additional database: GCSATPDEV
```

Verify that the database is **Available** and that Database Actions can be opened successfully.

A useful test is:

```sql
SELECT SYSDATE, USER
FROM DUAL;
```

The query should return successfully.

---

## 2. Verify Network Configuration

On the Autonomous Database details page, review the network configuration.

If the database requires mutual TLS (mTLS), the Database Tools connection must use an Oracle wallet.

The generated connection string will typically use:

```text
protocol=tcps
port=1522
```

---

## 3. Create or Select the Database Password Secret

OCI Database Tools does not store the database password directly in the connection. It references an OCI Vault **secret** containing the password for the database user.

For these connections the database user is:

```text
ADMIN
```

### Important distinction

The **Vault itself does not contain a database password when you create the Vault**.

The sequence is:

```text
1. Create or select a Vault
2. Create or select a master encryption key in that Vault
3. Create a password secret using that Vault and key
4. Put the ADMIN database password into that password secret
5. Select that secret in the Database Tools connection
```

If an appropriate password secret already exists and contains the current `ADMIN` password, simply select it. **Do not create another password secret unnecessarily.**

### Option A — Reuse Existing Vault Resources

Vaults, keys, and secrets do not have to reside in the same compartment as the Autonomous Database, provided OCI IAM permissions allow access.

For example, the original Greenville setup used shared resources in the root compartment.

When creating the Database Tools connection:

```text
Username: ADMIN
User password secret: <existing valid ADMIN password secret>
```

### Option B — Create Dedicated Resources in the Database Compartment

A team may instead keep its Database Tools resources in its own compartment.

For `GCSATPDEV`, the dedicated setup uses:

```text
Compartment: gcsd_OIC
Vault: GCSD_OIC_VAULT
Database: GCSATPDEV
Database user: ADMIN
```

#### 3.1 Create the Vault

Navigate to:

```text
Identity & Security
→ Key Management
→ Vault
```

Select:

```text
Compartment: gcsd_OIC
```

Click **Create Vault**.

Example:

```text
Name: GCSD_OIC_VAULT
```

Wait until the Vault state is:

```text
Active
```

Creating the Vault does **not** ask for or store the database password.

#### 3.2 Create the Master Encryption Key

Open:

```text
GCSD_OIC_VAULT
```

Select:

```text
Master encryption keys
→ Create Key
```

Use settings such as:

```text
Name: GCS OIC Vault Master Key1
Protection Mode: HSM
Key Shape / Algorithm: AES
Key Length: 256 bits
```

Use **HSM** for Protection Mode.

Wait until the key state is:

```text
Enabled
```

The master key encrypts secrets stored in the Vault. It is **not** the database password.

#### 3.3 Create the Password Secret

Return to the Database Tools **Create connection** page.

Configure the target database and enter:

```text
Username: ADMIN
```

Under the password-secret section, either select an existing secret or click:

```text
Create password secret
```

This is the point where the actual database password is entered.

In the **Create password secret** dialog, configure:

```text
Name: GCSATPDEV_ADMIN_PASSWORD
Description: ADMIN database password for GCSATPDEV Database Tools connection

Vault:
GCSD_OIC_VAULT

Encryption key:
GCS OIC Vault Master Key1

User password:
<actual ADMIN password for GCSATPDEV>

Confirm user password:
<same password>
```

Click **Create**.

Back on the Database Tools connection page, select the newly created secret as:

```text
User password secret:
GCSATPDEV_ADMIN_PASSWORD
```

If a secret is already visible in the dropdown—for example an `ADMIN` secret in `GCSD_OIC_VAULT`—and it contains the correct current database password, use it instead of creating another one.

> **Security:** Never place the actual database password in documentation, screenshots, Teams/Slack, email, or Git.

---

## 4. Create the Wallet Secret

If the connection requires mTLS, Database Tools also needs the Autonomous Database wallet.

Do **not** manually create a generic Plain-Text Vault secret containing Base64 wallet contents.

Database Tools expects the wallet secret to have the OCI content type:

```text
SSO_WALLET
```

Create the wallet secret from inside the Database Tools connection wizard.

Navigate to:

```text
Developer Services
→ Database Tools
→ Connections
→ Create connection
```

In **SSL details**, select:

```text
Wallet format:
Oracle auto-login wallet (e.g. cwallet.sso)
```

Then click:

```text
Create wallet content secret
```

Choose:

```text
Retrieve regional wallet from Autonomous AI Database
```

For the dedicated `GCSATPDEV` configuration, select:

```text
Vault:
GCSD_OIC_VAULT

Encryption key:
GCS OIC Vault Master Key1

Database:
GCSATPDEV
```

Give the wallet secret a descriptive name, for example:

```text
GCSATPDEV_WALLET
```

Database Tools retrieves the Autonomous Database wallet and creates the secret with the required:

```text
contentType = SSO_WALLET
```

This is preferable to downloading, extracting, encoding, or manually uploading `cwallet.sso`.

---

## 5. Create the Database Tools Connection

Navigate to:

```text
Developer Services
→ Database Tools
→ Connections
→ Create connection
```

Select the appropriate compartment and database.

For `GCSATPDEV`, the configuration is approximately:

```text
Connection name:
GCSATPDEV-ADMIN

Compartment:
gcsd_OIC

Database cloud service:
Oracle Autonomous AI Database

Database:
GCSATPDEV

Username:
ADMIN

User password secret:
ADMIN password secret in GCSD_OIC_VAULT

Private endpoint:
None, unless required by the database network configuration

Wallet format:
Oracle auto-login wallet

Wallet content secret:
GCSATPDEV wallet secret created through the Database Tools wizard
```

Click **Create**.

Wait for the connection state to become:

```text
Active
```

---

## 6. Validate the Database Tools Connection

**Do not proceed to the Fusion integration until this test works.**

Open the Database Tools connection and click:

```text
SQL worksheet
```

Run:

```sql
SELECT SYSDATE, USER
FROM DUAL;
```

Expected result:

```text
USER
-----
ADMIN
```

For `GCSATPDEV`, this validation was successfully completed using the `GCSATPDEV-ADMIN` Database Tools connection.

This proves that:

```text
Database Tools can reach the database
The ADMIN password secret is valid
The wallet configuration is valid
The JDBC connection is functioning
```

An OCI Database Tools connection can show **Active** even when the actual JDBC connection cannot be established, so the SQL Worksheet test is important.

---

## 7. Integrate APEX with Fusion Applications

Once the Database Tools connection has been validated:

```text
Database Tools
→ Connections
→ <working connection>
→ Actions
→ Integrate APEX with Fusion Applications
```

OCI will inspect the APEX database and display information including:

```text
Database
Database version
APEX version
APEX instance URL
```

Select the desired Fusion Applications environment.

For Greenville, environments include:

```text
IBZSJB-DEV2
IBZSJB-DEV4
IBZSJB-DEV6
IBZSJB-TEST
```

Use a descriptive integrated application name, for example:

```text
APEX_FA_DEV4_INTEGRATION_APP
APEX_FA_DEV2_INTEGRATION_APP
```

Do not alter the APEX instance URL generated by OCI.

Click:

```text
Integrate
```

Repeat for each Fusion environment that should be available to APEX.

---

## 8. Verify the Integration From APEX

Open APEX and create a new application.

Choose:

```text
Create Fusion Integration
```

The **Fusion Instance Name** dropdown should contain the configured Fusion environments.

For example:

```text
IBZSJB-DEV2
IBZSJB-DEV4
IBZSJB-DEV6
IBZSJB-TEST
```

Selecting an environment should populate the corresponding Fusion REST API configuration.

This confirms that OCI's Fusion integration is being recognized by APEX.

---

# Troubleshooting ORA-18714

If the integration wizard returns:

```text
ORA-18714: Login timeout specified by DataSource.setLoginTimeout(int)
or by the oracle.jdbc.loginTimeout property has expired.
```

do not immediately troubleshoot Fusion.

First determine whether the Database Tools connection itself works.

## Diagnostic Sequence

### Test 1 — Database Actions

Open the Autonomous Database directly and launch Database Actions.

Run:

```sql
SELECT SYSDATE, USER
FROM DUAL;
```

If this succeeds, the database itself is healthy.

### Test 2 — Database Tools SQL Worksheet

Open:

```text
Database Tools
→ Connection
→ SQL worksheet
```

Run the same query.

If the worksheet hangs or eventually returns ORA-18714, the problem is in the Database Tools connection path rather than the Fusion integration.

### Test 3 — Validate the Password Secret

Verify that the selected Vault password secret contains the current password for the database user.

For these configurations:

```text
Database user: ADMIN
```

If the secret already exists, there is no reason to create another secret unless the existing value is incorrect or obsolete.

### Test 4 — Validate the Wallet Secret

Verify that the Database Tools connection references a valid SSO wallet secret.

The wallet secret must have:

```text
contentType = SSO_WALLET
```

A generic Plain-Text secret containing Base64 wallet data is not equivalent.

If Database Tools reports:

```text
Invalid keyStores. Expected contentType: SSO_WALLET
```

create the wallet secret through:

```text
Create wallet content secret
→ Retrieve regional wallet from Autonomous AI Database
```

### Test 5 — Rebuild Safely

When troubleshooting an existing environment, create a separately named Database Tools connection rather than modifying a connection that may already be in use.

Use:

```text
Known-good database password secret
+
Fresh wallet secret
+
Same Autonomous Database
```

Then validate the new connection independently with SQL Worksheet.

---

# Important Safety Practice

When troubleshooting, **do not modify, rotate, replace, or delete existing connections, wallets, secrets, keys, or other OCI resources that may already be in use.**

Create separately named resources when necessary.

This allows the problem to be isolated without risking disruption to existing applications or integrations.

During the Greenville troubleshooting, the working solution was created without modifying the existing connections that were already in use.

Only clean up test resources after the replacement configuration has been validated and after confirming that no existing application depends on them.

---

# Greenville Configuration Summary

## Original APEX Database

```text
OCI database resource: GCSAPEX
Database name: FreeDemo
Database user: ADMIN
APEX version: 24.2.17
```

Working Database Tools connection:

```text
GCSAPEX_WalletTest
```

Fusion integrations created:

```text
DEV4
APEX_FA_DEV4_INTEGRATION_APP

DEV2
APEX_FA_DEV2_INTEGRATION_APP
```

APEX successfully discovered the configured Fusion environments through the **Create Fusion Integration** wizard.

## GCSATPDEV Database

```text
Database: GCSATPDEV
Compartment: gcsd_OIC
Database user: ADMIN

Vault:
GCSD_OIC_VAULT

Master encryption key:
GCS OIC Vault Master Key1
Protection Mode: HSM
Algorithm: AES

Database Tools connection:
GCSATPDEV-ADMIN
```

The Database Tools connection was successfully validated through SQL Worksheet with:

```sql
SELECT SYSDATE, USER
FROM DUAL;
```

returning:

```text
USER
-----
ADMIN
```

---

# Key Lesson

The **Integrate APEX with Fusion Applications** process depends on a functioning OCI Database Tools JDBC connection.

The reliable order of operations is:

```text
1. Identify the Autonomous Database
2. Verify database/network configuration
3. Create or select a Vault
4. Create or select a master encryption key
5. Create or select the ADMIN password secret
6. Create the SSO wallet secret through Database Tools
7. Create the Database Tools connection
8. Validate it using SQL Worksheet
9. Integrate APEX with the desired Fusion environment
10. Verify the Fusion environment appears in APEX
```

A successful Database Tools connection should satisfy all of the following:

```text
Autonomous Database is available
Database credentials are valid
Password secret contains the correct database password
mTLS wallet is valid when required
Wallet secret has SSO_WALLET content type
Database Tools SQL Worksheet opens
SQL executes successfully as ADMIN
Fusion environment can be selected by the integration wizard
APEX can see the Fusion environment afterward
```
