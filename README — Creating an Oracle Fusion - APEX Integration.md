# Creating an Oracle Fusion / APEX Integration

This document describes the process for connecting an Oracle APEX environment to one or more Oracle Fusion Applications environments using OCI Database Tools.

It also documents the troubleshooting steps we used when the integration wizard returned:

```text
ORA-18714: Login timeout specified by DataSource.setLoginTimeout(int)
or by the oracle.jdbc.loginTimeout property has expired.
```

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

For the Greenville environment:

```text
OCI resource: GCSAPEX
Database name: FreeDemo
Workload type: Transaction Processing
```

Verify that the database is available and that APEX/Database Actions can be opened successfully.

A useful test is:

```sql
select sysdate, user from dual;
```

The query should return successfully.

---

## 2. Verify Network Configuration

On the Autonomous Database details page, review the **Network** section.

The Greenville database currently uses:

```text
Access type: Allow secure access from everywhere
Access control list: Disabled
mTLS authentication: Required
```

Because mTLS is required, the Database Tools connection must use an Oracle wallet.

The generated connection string will typically use:

```text
protocol=tcps
port=1522
```

---

## 3. Create the Database Password Secret

OCI Database Tools does not store the database password directly in the connection. The password must first be stored as a secret in OCI Vault.

You will need the password for the database user that Database Tools will use to connect to the target Autonomous Database. In our configuration, this is the `ADMIN` database user.

When creating the Database Tools connection, enter:

```text
Username: ADMIN
```

Then click:

```text
Create password secret
```

Create a new secret containing the `ADMIN` password for the target Autonomous Database.

For example:

```text
Name: <DATABASE_NAME>_ADMIN_PASSWORD
Description: ADMIN database password for <DATABASE_NAME> Database Tools connection
Vault: Test_vault
Encryption key: Test_Key
User password: <ADMIN password for the target database>
Confirm user password: <same password>
```

The Vault and encryption key do **not** need to reside in the same compartment as the target Autonomous Database. An existing Vault and encryption key in another compartment can be used, provided the appropriate OCI IAM permissions allow access.

For the Greenville environment, the existing resources are:

```text
Vault: Test_vault
Encryption key: Test_Key
Compartment: gcsd (root)
```

After the secret is created, select it as the **User password secret** on the Database Tools connection.

If a password secret already exists for the target database and its credentials are known to be current, it can be reused instead of creating a new one.

### Verify the Credential

Before proceeding, verify that the database credential is valid if possible.

For example, log into Database Actions using:

```text
Username: ADMIN
Password: <password stored in the secret>
```

A simple database test is:

```sql
SELECT SYSDATE, USER
FROM DUAL;
```

The expected user is:

```text
ADMIN
```

If Database Actions is unavailable or fails to load, credential validation can also be performed later through the SQL Worksheet associated with the Database Tools connection.

> **Security:** Do not expose database passwords or decoded secret values in screenshots, documentation, Teams/Slack, email, or Git.

---

### Option: Create Dedicated Vault Resources in the Database Compartment

The existing Vault and encryption key can be reused across compartments when IAM permissions allow it. However, a team may prefer to keep all Database Tools resources associated with a database in the same compartment.

For example, for `GCSATPDEV` in the `gcsd_OIC` compartment, either of the following approaches is valid:

```text
Option A — Reuse existing resources
Vault: Test_vault
Encryption key: Test_Key
Compartment: gcsd (root)

Option B — Create dedicated resources
Vault: GCS_OIC_Vault
Encryption key: GCS_OIC_Key
Compartment: gcsd_OIC
```

Option B provides cleaner ownership and resource organization for teams that manage their own OCI compartment.

#### Create a Dedicated Vault

Navigate to:

```text
Identity & Security
→ Vault
```

Select:

```text
Compartment: gcsd_OIC
```

Click **Create Vault** and use a descriptive name, for example:

```text
GCS_OIC_Vault
```

Wait for the Vault to become **Active**.

#### Create a Dedicated Encryption Key

Open the new Vault and create a Master Encryption Key.

For example:

```text
GCS_OIC_Key
```

Wait for the key to become **Enabled**.

#### Create a Dedicated Database Password Secret

When creating the Database Tools connection, enter:

```text
Database: GCSATPDEV
Username: ADMIN
```

Click:

```text
Create password secret
```

Create the secret using the dedicated Vault and key:

```text
Name: GCSATPDEV_ADMIN_PASSWORD

Description:
ADMIN database password for GCSATPDEV Database Tools connection

Vault:
GCS_OIC_Vault

Encryption key:
GCS_OIC_Key

User password:
<ADMIN password for GCSATPDEV>

Confirm user password:
<same password>
```

After creation, select:

```text
User password secret:
GCSATPDEV_ADMIN_PASSWORD
```

#### Create a Dedicated Wallet Secret

Continue to the **SSL details** section of the Database Tools connection.

Select:

```text
Wallet format:
Oracle auto-login wallet (e.g. cwallet.sso)
```

Click:

```text
Create wallet content secret
```

Choose:

```text
Retrieve regional wallet from Autonomous AI Database
```

Create the wallet secret using the dedicated Vault and key:

```text
Name:
GCSATPDEV_WALLET

Description:
Autonomous Database wallet for GCSATPDEV Database Tools connection

Vault:
GCS_OIC_Vault

Encryption key:
GCS_OIC_Key

Database:
GCSATPDEV
```

Database Tools will retrieve the Autonomous Database wallet and create the secret with the required:

```text
contentType = SSO_WALLET
```

Do **not** create a generic Plain-Text Vault secret containing Base64 wallet contents.

#### Resulting Dedicated Configuration

The completed Database Tools connection would use resources similar to:

```text
Connection name:
GCSATPDEV_Fusion

Compartment:
gcsd_OIC

Database:
GCSATPDEV

Username:
ADMIN

Password secret:
GCSATPDEV_ADMIN_PASSWORD

Vault:
GCS_OIC_Vault

Encryption key:
GCS_OIC_Key

Wallet secret:
GCSATPDEV_WALLET
```

This configuration is functionally equivalent to using shared Vault resources. The difference is organizational: the Vault, key, password secret, wallet secret, database, and Database Tools connection can all be managed within the team's `gcsd_OIC` compartment.

Creating these dedicated resources does **not** require modifying or deleting any existing Vaults, keys, secrets, wallets, or Database Tools connections.

---

## 4. Create the Wallet Secret Correctly

Do **not** manually create a generic Plain-Text Vault secret containing Base64 wallet contents.

Database Tools expects the wallet secret to have the OCI content type:

```text
SSO_WALLET
```

Instead, create the wallet secret from inside the Database Tools connection wizard.

Navigate to:

```text
Developer Services
→ Database Tools
→ Connections
→ Create connection
```

In the **SSL details** section:

```text
Wallet format:
Oracle auto-login wallet (e.g. cwallet.sso)
```

Click:

```text
Create wallet content secret
```

Choose:

```text
Retrieve regional wallet from Autonomous AI Database
```

Then select:

```text
Vault:       appropriate OCI Vault
Encryption key: appropriate encryption key
Database:    GCSAPEX
```

Database Tools will retrieve the wallet and create the Vault secret using the correct `SSO_WALLET` content type.

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

Configure:

```text
Database cloud service:
Oracle Autonomous AI Database

Database:
GCSAPEX

Username:
ADMIN

User password secret:
DemoSecret

Private endpoint:
None

Wallet format:
Oracle auto-login wallet

SSO wallet content secret:
Wallet secret created through the Database Tools wizard
```

Use a descriptive connection name, for example:

```text
GCSAPEX_WalletTest
```

After creation, wait for the connection state to become:

```text
Active
```

---

## 6. Validate the Database Tools Connection

Open the newly created connection and click:

```text
SQL worksheet
```

The SQL Worksheet should load without hanging.

Run:

```sql
select sysdate, user from dual;
```

Expected result:

```text
USER
-----
ADMIN
```

If this succeeds, the Database Tools connection is working.

This validation is important because an OCI Database Tools connection can show a state of **Active** even when the actual JDBC connection cannot be established.

---

## 7. Integrate APEX with Fusion Applications

From the working Database Tools connection:

```text
Actions
→ Integrate APEX with Fusion Applications
```

OCI will inspect the APEX database and display information such as:

```text
Database
Database version
APEX version
APEX instance URL
```

Select the desired Fusion Applications environment.

For Greenville, examples include:

```text
IBZSJB-DEV2
IBZSJB-DEV4
IBZSJB-DEV6
IBZSJB-TEST
```

Use a descriptive integrated application name.

Examples:

```text
APEX_FA_DEV4_INTEGRATION_APP
APEX_FA_DEV2_INTEGRATION_APP
```

Do not alter the APEX instance URL generated by OCI.

Click:

```text
Integrate
```

Repeat this process for each Fusion environment that should be available to APEX.

---

## 8. Verify the Integration From APEX

Open APEX and create a new application.

Choose:

```text
Create Fusion Integration
```

The **Fusion Instance Name** dropdown should now contain the configured Fusion environments.

For example:

```text
IBZSJB-DEV2
IBZSJB-DEV4
IBZSJB-DEV6
IBZSJB-TEST
```

Selecting an environment should populate the corresponding Fusion REST API configuration.

This confirms that the OCI Fusion integration is being recognized by APEX.

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

If SQL works there:

```text
Database itself is healthy.
```

### Test 2 — Database Tools SQL Worksheet

Open:

```text
Database Tools
→ Connection
→ SQL worksheet
```

If the worksheet hangs or eventually returns ORA-18714:

```text
The problem is in the Database Tools connection path.
```

### Test 3 — Validate Password

Verify that the Vault password secret still contains the current database password.

For example, confirm that the password stored in `DemoSecret` can log into Database Actions as:

```text
ADMIN
```

A wrong password would normally produce an authentication failure rather than a multi-minute JDBC login timeout.

### Test 4 — Wallet

Verify that the Database Tools connection references a valid SSO wallet secret.

The wallet secret must be created with:

```text
contentType = SSO_WALLET
```

A generic Plain-Text secret containing Base64 wallet data is not equivalent.

If Database Tools reports:

```text
Invalid keyStores. Expected contentType: SSO_WALLET
```

create the wallet secret using:

```text
Create wallet content secret
→ Retrieve regional wallet from Autonomous AI Database
```

### Test 5 — Rebuild Instead of Modifying Production Resources

When troubleshooting, create a new Database Tools connection rather than modifying an existing connection.

For example:

```text
GCSAPEX_WalletTest
```

Use:

```text
Known-good database password secret
+
Fresh wallet secret
+
Same Autonomous Database
```

Then validate the connection independently.

---

# Important Safety Practice

When troubleshooting, **do not modify, rotate, replace, or delete existing connections, wallets, secrets, or other OCI resources that may already be in use.**

Use separately named test resources.

This allows the problem to be isolated without risking disruption to existing applications or integrations.

During the Greenville troubleshooting, the working solution was created entirely with new resources. Existing connections and resources were left untouched.

Only clean up test resources after the replacement configuration has been validated and after confirming that no existing application depends on them.

---

# Greenville Configuration Summary

Current APEX database:

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

APEX can now discover the Greenville Fusion environments through the **Create Fusion Integration** wizard.

---

# Key Lesson

The **Integrate APEX with Fusion Applications** process depends on a functioning OCI Database Tools JDBC connection.

If the Fusion integration wizard fails with a database login timeout, validate the Database Tools connection first.

A successful connection should satisfy all of the following:

```text
Autonomous Database is available
Database credentials are valid
Database Tools can open SQL Worksheet
SQL can execute successfully
mTLS wallet is valid
Wallet secret has SSO_WALLET content type
Fusion environment can be selected by the integration wizard
APEX can see the Fusion environment afterward
```

Once those pieces are in place, creating additional Fusion integrations for environments such as DEV2, DEV4, DEV6, or TEST is straightforward.