# Google Workspace (gog) setup — what's left to do

The `gog` CLI and its agent skills are installed locally. What's left requires
your own Google sign-ins and console access, so it can't be automated.

## Already done

- `gog` v0.34.0 installed to `%LOCALAPPDATA%\Programs\gog\` and added to your
  user PATH.
- Agent skills installed to `~/.claude/skills/`: `gog`, `gog-docs`,
  `gog-sheets`, `gog-drive`, `gog-slides`, `gog-gmail`, `gog-calendar`.
- House style + workflow skill added at
  [skills/google-workspace/SKILL.md](SKILL.md), junctioned into
  `~/.claude/skills/google-workspace`.

## What you need to do

### 1. Create a Google Cloud project (~2 min)

Sign in with any of your three accounts (personal is fine — one OAuth app
can authorize all three later).

- [console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate)
- Name it something like `gog-cli`.

### 2. Enable the required APIs (~2 min)

With the new project selected, open each link and click **Enable**:

- [Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com)
- [Docs API](https://console.cloud.google.com/apis/library/docs.googleapis.com)
- [Sheets API](https://console.cloud.google.com/apis/library/sheets.googleapis.com)
- [Slides API](https://console.cloud.google.com/apis/library/slides.googleapis.com)
- [Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com)
- [Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)

### 3. Configure the OAuth consent screen (~2 min)

- [console.cloud.google.com/auth/branding](https://console.cloud.google.com/auth/branding)
- Audience: **External**
- Fill in app name and your email.

### 4. Publish to Production

- On the **Audience** page, click **Publish app**.
- Important: skipping this leaves the app in Testing mode, where logins
  expire every 7 days. No Google verification review is required for this
  use case — you'll just click through an "unverified app" warning once per
  account during sign-in.

### 5. Create the OAuth client (~1 min)

- [console.cloud.google.com/auth/clients](https://console.cloud.google.com/auth/clients)
- **Create client** → type **Desktop app**.
- Download the client JSON and note where you saved it.

### 6. Hand back to Claude

Tell Claude:

- Where the downloaded client JSON file is.
- The three account emails and which alias each should map to
  (`personal` / `work` / `org` — see [SKILL.md](SKILL.md#account-routing)).

Claude will then run, per account:

```bash
gog auth credentials <path-to-client_secret.json>
gog auth add <email> --services gmail,calendar,drive,docs,sheets,slides
gog auth alias set <alias> <email>
```

Each `auth add` opens a browser tab for you to approve access. After all
three accounts are added, Claude will verify with `gog auth doctor --check`
and run an end-to-end test: create a sample styled Doc and Sheet in your
Drive so you can confirm it looks right.

## Note on the company Workspace account

If your Workspace restricts third-party apps, sign-in may show "blocked by
admin" for the `work` account. Since you're admin there, fix it via:

**Admin console → Security → API controls → App access control** — allow
the OAuth client you created in step 5. Only needed if you actually hit
this error.
