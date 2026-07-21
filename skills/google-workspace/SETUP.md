# Google Workspace (gog) setup — Mac

Status: **complete on Oli's Mac** (2026-07-21). All three accounts are authorized and
verified. This doc is the runbook for re-doing it on a new machine.

Tool source: [gogcli.sh](https://gogcli.sh) · CLI reference: `gog schema <cmd>` / `gog <cmd> --help`.

## Current state (this Mac)

- `gog` installed via Homebrew, on PATH at `/opt/homebrew/bin/gog`.
- Google Cloud project `gog-cli` (`gog-cli-503117`) under the **personal** account, with a
  single shared **External / Desktop app** OAuth client authorizing all three accounts.
  Consent screen published to **Production** (no 7-day token expiry).
- Accounts authorized, tokens in macOS Keychain:

  | Alias      | Email                        |
  |------------|------------------------------|
  | `personal` | oli.ingram.design@gmail.com  |
  | `work`     | oli@wonderstudios.com        |
  | `org`      | oli@subsolar.studio          |

- Verify anytime: `gog auth doctor --check` and `gog auth alias list`.

> Note: the `gog-docs` / `gog-sheets` / … service skills are **not** installed here. The
> Homebrew formula ships the CLI only; use `gog schema` / `--help` for syntax. Only the
> `google-workspace` house-style skill (this folder) is present.

## Re-doing it on a new machine

### 1. Install gog

```bash
brew install openclaw/tap/gogcli
gog --version
```

(Other options — direct binary or build from source — at [gogcli.sh/install.html](https://gogcli.sh/install.html).)

### 2. Google Cloud OAuth setup (once, under the personal account)

Only needed if not reusing the existing `gog-cli` project's client JSON. Sign in with the
**personal** account (one External client authorizes all three accounts).

1. **Create project** → [console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate), name `gog-cli`.
   - This account requires a billing account on the project; the Workspace APIs used are
     free-tier, so attaching one incurs no charges.
2. **Enable APIs** (click Enable on each): Drive, Docs, Sheets, Slides, Gmail, Calendar.
3. **Consent screen** → [auth/branding](https://console.cloud.google.com/auth/branding) →
   Get started → app name `gog-cli`, support email, Audience **External**, contact email.
4. **Publish to Production** → [auth/audience](https://console.cloud.google.com/auth/audience) →
   Publish app → Confirm. (Skipping this = logins expire every 7 days. No Google
   verification review is needed for personal use — just click past the "unverified app"
   warning once per account at sign-in.)
5. **Create OAuth client** → [auth/clients](https://console.cloud.google.com/auth/clients) →
   Create client → type **Desktop app** → download the client JSON.

### 3. Authorize each account

```bash
gog auth credentials ~/Downloads/client_secret_*.json          # once; secret goes to Keychain
gog auth add <email> --services gmail,calendar,drive,docs,sheets,slides   # per account
gog auth alias set <alias> <email>                              # personal | work | org
```

Each `gog auth add` opens a browser tab: pick the account → Advanced → Go to gog-cli
(unsafe) → Allow. Then `gog auth doctor --check` should report `status ok`.

## Company Workspace note

If a Workspace restricts third-party apps, `gog auth add` shows "blocked by admin" for that
account. As admin, allow the OAuth client via **Admin console → Security → API controls →
App access control**. (Not needed for `work`/`org` above — both signed in cleanly.)
