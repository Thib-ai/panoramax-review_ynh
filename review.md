# Review: panoramax-review_ynh (YunoHost package)

Overall assessment: **well-structured package**. Proper manifest v2, all 6 scripts (install/upgrade/remove/backup/restore/change_url), good systemd hardening, logrotate, env file template. The `change_url` script is a nice addition not in the spec.

Below are issues grouped by severity. Each has a specific fix request.

---

## CRITICAL — breaks core functionality

### C1. Sub-path installs are broken (nginx side)

**File:** `conf/nginx.conf:4`

```nginx
proxy_pass http://127.0.0.1:__PORT__;
```

Without a trailing slash, nginx passes the full URI (e.g. `/review/api/auth/me`) to the backend, but the backend expects `/api/auth/me`. If installed at root (`/`), this works. If installed at `/review` (the manifest default), every API call 404s.

**Fix:** Add trailing slash:
```nginx
proxy_pass http://127.0.0.1:__PORT__/;
```

The matching frontend-side fix is documented in the app repo's review (the frontend's `api.ts` needs to prefix API calls with `import.meta.env.BASE_URL`).

### C2. Install/upgrade scripts don't pass `VITE_BASE_PATH` to the build

**Files:** `scripts/install:31`, `scripts/upgrade:28`

```bash
(cd "$install_dir" && npm run build)
```

Even after the frontend is fixed to read `import.meta.env.BASE_URL`, the build needs `VITE_BASE_PATH` set to the install path. Without it, `BASE_URL` defaults to `/` and sub-path installs still break.

**Fix (both scripts):**
```bash
(cd "$install_dir" && VITE_BASE_PATH="$path/" npm run build)
```

`$path` is the install path from the manifest (e.g. `/review`). For root installs (`path=/`), `VITE_BASE_PATH=/` is fine.

---

## IMPORTANT — degrades UX or correctness

### I1. POST_INSTALL.md lists nonexistent keyboard shortcuts

**File:** `doc/POST_INSTALL.md:12-16`

```
Key shortcuts during review:
- `1`-`9` — error categories
- `Enter` — submit review
- `U` — undo last review
- `F` — toggle fullscreen
```

None of these exist in the app except `Enter` (OK) and `U` (undo). There are no 1-9 error category shortcuts and no fullscreen toggle. This is misleading.

**Fix:** Replace with the actual shortcuts from the spec:
```markdown
Key shortcuts during review:
- `Enter` or `O` — mark as OK (pass)
- `E` or `F` — flag an issue (opens error modal)
- `S`, `→`, `←`, `↑`, `↓`, `Space` — skip to next image
- `Z` or `Ctrl+Z` — undo last review
```

### I2. Install script references undefined `$admin` variable

**File:** `scripts/install:13`

```bash
admin_mail=$(ynh_user_get_info --username=$admin --key=mail)
```

The manifest doesn't define an `admin` install question, so `$admin` is empty. `admin_mail` is then set to empty and never used. This line will either error or silently produce garbage.

**Fix:** Delete line 13 entirely. The app doesn't use an admin email.

### I3. manifest.toml source URL, code link, and sha256 are placeholders

**File:** `manifest.toml:17, 48-49`

```toml
code = "https://github.com/username/panoramax-review"
url = "https://github.com/username/panoramax-review/archive/refs/tags/v1.0.0.tar.gz"
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
```

All three are placeholders. The install will fail because `ynh_setup_source` will try to download from `github.com/username/...` and either 404 or fail the sha256 check.

**Fix:** Update to the real GitHub repo URL and compute the actual sha256 of the release tarball. If the repo isn't published yet, at minimum set `sha256` to an empty string (YunoHost will skip the check) and add a comment noting this needs to be filled in before release.

---

## MINOR — cosmetic or nice-to-have

### M1. `manifest.toml`: `multi_instance = false`

The spec said `multi_instance = true`. A user might want separate instances on different paths (e.g. different Panoramax instances). Not critical, but the app is lightweight enough to support it.

### M2. `manifest.toml`: `id = "panoramax_review"` (underscore)

The spec and the app repo both use `panoramax-review` (hyphen). YunoHost convention is hyphens. Change to `panoramax-review`.

### M3. `manifest.toml`: `yunohost = ">= 12.1.39"`

The spec said `>= 11.0`. YunoHost 12 is very new and excludes many stable installations. The app doesn't use any YunoHost 12-specific features. Consider lowering to `>= 11.0` or `>= 11.2`.

### M4. `manifest.toml`: `helpers_version = "2.1"`

This requires a recent YunoHost. If you lower the min version to 11.x, verify that helpers 2.1 are available. If not, use `helpers_version = "2.0"`.

### M5. `manifest.toml`: `architectures = ["amd64", "arm64"]`

The spec said `all`. `better-sqlite3` has prebuilt binaries for amd64 and arm64, but also for armv7 (32-bit ARM, used by Raspberry Pi 3/4). Consider adding `"armhf"` or setting `"all"` and letting `better-sqlite3` fall back to source build (the manifest already installs `build-essential` and `python3`).

### M6. `install` script: npm commands run as root

**File:** `scripts/install:27-35`

```bash
(cd "$install_dir" && npm ci ...)
(cd "$install_dir" && npm run build)
```

These run as root, which means `node_modules/` will be owned by root. The systemd service then runs as `$app`, which is fine for reading, but any future npm operations might have permission issues. Consider wrapping in `ynh_exec_as $app`:

```bash
ynh_exec_as $app npm ci --omit=optional --no-audit --no-fund
```

Note: `ynh_exec_as` may need the `$app` user to have a home directory for npm cache. YunoHost's `system_user` resource should handle this.

### M7. `install` script: missing `chown` after build

After `npm ci` and `npm run build` run as root, the `install_dir` files are owned by root. The systemd `User=__APP__` needs read access (fine — world-readable by default), but the `.env` file created by `ynh_config_add` should be owned by `$app`. Add after the build:

```bash
chown -R $app:$app "$install_dir"
```

But NOT `data_dir` — YunoHost's `resources.data_dir` already handles that.

### M8. `systemd.service`: `ProtectSystem=full` vs `strict`

The spec recommended `strict`. `full` allows writes to `/etc`, which the app doesn't need. Consider `strict` with `ReadWriteDirectories` listing only what's needed. Not a security issue since the systemd user is dedicated, but defense-in-depth.

---

## What's done well

- **Manifest**: proper v2 format with resources block (system_user, install_dir, data_dir, ports, permissions, nodejs, apt), autoupdate strategy configured.
- **Scripts**: all 6 lifecycle scripts present and using YunoHost helpers correctly (`ynh_setup_source`, `ynh_config_add_nginx`, `ynh_config_add_systemd`, `ynh_systemctl`, `ynh_backup`/`ynh_restore`, `ynh_config_add_logrotate`). The `change_url` script is a nice addition.
- **systemd.service**: strong hardening — `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, `ProtectSystem`, `ProtectKernelModules`, `SystemCallFilter`, comprehensive `CapabilityBoundingSet` denials. Better than the spec's example.
- **nginx.conf**: includes `proxy_params_with_auth` (which sets the auth headers including `X-Remote-User`), proper timeouts, `client_max_body_size 25M` for imports, security headers.
- **Env file template**: clean separation of env config via `panoramax-review.env` with `__PORT__` and `__DATA_DIR__` placeholders.
- **tests.toml**: declares an upgrade test from 1.0.0~ynh1.
