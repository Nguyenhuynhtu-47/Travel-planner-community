# Travel Planner — Email & SMTP Configuration & Troubleshooting Guide

## 1. Overview & Architecture

Travel Planner uses an asynchronous, transactional event-driven architecture for delivering authentication emails (Email Verification OTP and Password Reset OTP).

### 1.1. Delivery Pipeline Flow
```
User Action (Register / Forgot Password)
       │
       ▼
AuthController (POST /api/auth/register or /forgot-password)
       │
       ▼
AuthService / EmailVerificationService / PasswordResetService
       │
       ├─► DB Transaction: Generates 6-digit OTP, computes HMAC-SHA256, saves token to MySQL
       │
       ├─► Publishes ApplicationEvent (UserVerificationEvent / UserPasswordResetEvent)
       │
       ▼
Transaction Commits (AFTER_COMMIT)
       │
       ▼
TransactionalEventListener (phase = AFTER_COMMIT, fallbackExecution = true)
       │ (dispatched asynchronously via @Async applicationTaskExecutor)
       ▼
EmailService.sendVerificationEmail() / sendPasswordResetEmail()
       │
       ├── If APP_MAIL_ENABLED=false (default dev mode):
       │     Logs simulation notice to console:
       │     "--- [EmailService] Mail disabled (app.mail.enabled=false). Simulating verification email to te***@example.com ---"
       │     (NO actual email is sent over the network)
       │
       └── If APP_MAIL_ENABLED=true:
             Renders Thymeleaf HTML template (`templates/mail/*.html`)
             Connects to SMTP Server via JavaMailSender
             Dispatches MIME message over TLS/STARTTLS
```

---

## 2. Why Emails Are Not Delivered by Default

By design, local development and test runs default to:
```properties
app.mail.enabled=false
```
When `app.mail.enabled` is `false`, the system operates in **Simulation Mode**:
- OTP tokens are securely generated, pepper-hashed, and stored in MySQL.
- API responses return generic success messages (`requiresVerification: true`).
- The system logs a simulation entry in the console without contacting any external network socket.
- **No real email is delivered to the user's inbox until SMTP is explicitly configured and enabled.**

---

## 3. Step-by-Step SMTP Setup Instructions

To enable live email delivery, create or update `.env` in `Travel_Planner/` (or the project root) with valid SMTP credentials.

### Option A: Real Gmail SMTP (Recommended for Personal Dev & Staging)
Gmail requires a **16-character Google App Password** (regular account passwords will fail authentication).

1. Go to your Google Account: [https://myaccount.google.com/security](https://myaccount.google.com/security).
2. Enable **2-Step Verification** (2FA) if not already enabled.
3. Search for **App passwords** (or go to [https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)).
4. Create an App password (e.g. name it "Travel Planner Backend").
5. Copy the generated 16-character password (e.g., `abcd efgh ijkl mnop`).
6. Add the following to your `.env` file:

```properties
# Enable live email delivery
APP_MAIL_ENABLED=true

# Gmail SMTP Configuration
SPRING_MAIL_HOST=smtp.gmail.com
SPRING_MAIL_PORT=587
SPRING_MAIL_USERNAME=your_email@gmail.com
SPRING_MAIL_PASSWORD=abcdefghijklmnop
SPRING_MAIL_FROM=your_email@gmail.com
SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_REQUIRED=true
SPRING_MAIL_TIMEOUT_MS=5000
```

> [!IMPORTANT]
> The `SPRING_MAIL_FROM` address must match the authenticated `SPRING_MAIL_USERNAME` when using Gmail SMTP. Otherwise, Google may rewrite the From header or reject delivery with `550 5.7.1 Client does not have permissions to send on behalf of the from address`.

---

### Option B: Local SMTP Mock Server (MailHog or Mailpit)
For development without sending real emails to external mailboxes:

1. Run Mailpit via Docker:
   ```bash
   docker run -d --name mailpit -p 1025:1025 -p 8025:8025 axllent/mailpit
   ```
2. Configure `.env`:
   ```properties
   APP_MAIL_ENABLED=true
   SPRING_MAIL_HOST=localhost
   SPRING_MAIL_PORT=1025
   SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=false
   SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=false
   SPRING_MAIL_FROM=no-reply@travelplanner.local
   ```
3. View all sent emails in your browser at `http://localhost:8025`.

---

### Option C: Production Transactional Email Services (SendGrid, Brevo, AWS SES)

#### Brevo (formerly Sendinblue):
```properties
APP_MAIL_ENABLED=true
SPRING_MAIL_HOST=smtp-relay.brevo.com
SPRING_MAIL_PORT=587
SPRING_MAIL_USERNAME=your_brevo_login_email
SPRING_MAIL_PASSWORD=your_brevo_smtp_master_key
SPRING_MAIL_FROM=verified_sender@yourdomain.com
SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_REQUIRED=true
SPRING_MAIL_TIMEOUT_MS=5000
```

---

## 4. Manual SMTP Smoke-Test Procedure

We have provided a dedicated manual smoke-test utility: `ManualSmtpSmokeTest.java`.
You can verify your SMTP credentials from the terminal without starting the full backend server:

```powershell
$env:SPRING_MAIL_HOST="smtp.gmail.com"
$env:SPRING_MAIL_PORT="587"
$env:SPRING_MAIL_USERNAME="your_email@gmail.com"
$env:SPRING_MAIL_PASSWORD="your_16_char_app_password"
$env:TEST_RECIPIENT_EMAIL="your_email@gmail.com"

cd Travel_Planner\backend
.\mvnw.cmd test -Dtest=ManualSmtpSmokeTest
```

Expected output:
```
=== [ManualSmtpSmokeTest] SUCCESS: Email dispatched to your_email@gmail.com via smtp.gmail.com:587 ===
```

---

## 5. Troubleshooting Checklist

| Symptom / Log Error | Root Cause | Solution |
| :--- | :--- | :--- |
| `Mail disabled (app.mail.enabled=false). Simulating verification email...` | `APP_MAIL_ENABLED` is `false` or unset. | Add `APP_MAIL_ENABLED=true` to your `.env` file and restart backend. |
| `535-5.7.8 Username and Password not accepted` | Using standard Google account password instead of App Password, or 2FA disabled. | Generate a dedicated 16-character App Password in Google Account Security settings. |
| `530 5.7.0 Must issue a STARTTLS command first` | Port 587 requires STARTTLS. | Set `SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true` and `SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_REQUIRED=true`. |
| `Connection timed out` or `MailConnectException` | Port 587 or 465 blocked by local ISP, antivirus, or firewall. | Check outbound port 587 connectivity via `Test-NetConnection smtp.gmail.com -Port 587`. |
| Email sent successfully according to logs, but inbox is empty | Mailbox filtering / Junk / Spam. | Check Spam/Junk folder. Ensure `SPRING_MAIL_FROM` matches the authenticated SMTP user. |
