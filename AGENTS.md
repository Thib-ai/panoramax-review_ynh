# Panoramax Review YunoHost package

YunoHost v2 package for [panoramax-review](https://github.com/Thib-ai/panoramax-review), a SvelteKit app that builds to `dist/server.cjs`.

## Structure

| Path | Purpose |
|---|---|
| `manifest.toml` | App manifest (Node.js 22, port 4983, SSO auth) |
| `scripts/{install,upgrade,remove,backup,restore,change_url}` | Lifecycle scripts |
| `conf/nginx.conf` | Reverse proxy with trailing-slash proxy_pass to strip path prefix |
| `conf/systemd.service` | Hardened systemd unit (ProtectSystem=strict, private tmp/dev, no new privs) |
| `conf/panoramax-review.env` | Env template: `NODE_ENV`, `PORT`, `DATA_DIR` |
| `doc/` | YunoHost install docs |
| `review.md` | Historical code review (issues mostly fixed; keep for reference) |

## Environment

**You are most likely NOT running on a YunoHost machine.** Don't assume YunoHost helpers, the `yunohost` CLI, or `/usr/share/yunohost/` are available locally — they only exist on the target install host. The package scripts (`scripts/*`) are executed by YunoHost on the install host, not in this dev repo.

When you need to look up YunoHost behaviour (helper signatures, manifest schema, resource provisioning), use the local copies of the source and docs:

- `/home/thibaultmol/git/yunohost documentation/yunohost source code/` — YunoHost core source (helpers in `helpers/helpers.v2.1.d/`, resource logic in `src/utils/resources.py`)
- `/home/thibaultmol/git/yunohost documentation/official yunohost docs/` — Docusaurus docs (manifest schema in `docs/dev/50.packaging/10.manifest.mdx`)

## Key commands

The package uses YunoHost helpers (`v2.1`). All scripts source `/usr/share/yunohost/helpers`.

```bash
# Install locally (for testing)
sudo yunohost app install /path/to/panoramax-review_ynh -a "domain=your.domain.tld&path=/review"
```

## Critical gotchas

- **proxy_pass must have trailing slash** (`http://127.0.0.1:__PORT__/`) so nginx strips the sub-path before forwarding. Without it, sub-path installs (e.g. `/review/api/...`) break with 404.
- **Don't duplicate what `proxy_params_with_auth` already sets**: that include already defines `Host`, `X-Real-IP`, `X-Forwarded-*`, `proxy_http_version 1.1`, `Upgrade`, and `Connection`. Re-declaring `proxy_http_version` in particular is a fatal nginx error (`"proxy_http_version" directive is duplicate`).
- **VITE_BASE_PATH must be set at build time** for sub-path installs to work. Both `scripts/install` and `scripts/upgrade` pass `VITE_BASE_PATH="$path/"` before `npm run build`.
- **`manifest.toml` source URL + sha256 are placeholder** — `sha256` is empty (skips check). Must be filled before release.
- **npm commands run as `$app` user** via `ynh_exec_as_app` (not root). The `$app` user needs a home dir for npm cache. Note: helpers v2.1 dropped the generic `ynh_exec_as $user` in favor of `ynh_exec_as_app` (which uses `$app` automatically), so the manifest must declare `helpers_version = "2.1"` — `2.0` resolves to a non-existent `helpers.v2.0.d/` dir and breaks the nodejs resource provisioning.
- **chown after build**: `chown -R $app:$app "$install_dir"` runs after npm build so the app user owns all files.
- **Don't use `npm --omit=optional`**: the app's build toolchain (rolldown/vite) ships its native bindings as npm *optional* dependencies keyed by platform/arch (e.g. `@rolldown/binding-linux-x64-gnu`). Skipping optional deps makes `npm run build` fail with "Cannot find native binding". `npm ci` and `npm prune` only pass `--omit=dev`, never `--omit=optional`.
- **Env file**: only sets `NODE_ENV=production`, `PORT=__PORT__`, `DATA_DIR=__DATA_DIR__`. Add new vars here and re-run `ynh_config_add`.
- **YunoHost SSO**: `auth_header = true` — the app reads `X-Remote-User` header set by nginx (via `proxy_params_with_auth`). No LDAP.

## Testing

```bash
# Test an upgrade from previous version
sudo yunohost app upgrade panoramax-review -u /path/to/panoramax-review_ynh --force
```

`tests.toml` declares a single upgrade test from `1.0.0~ynh1`.

## Conventions

- Scripts use `ynh_script_progression` for user-facing progress messages.
- System config re-applied on every upgrade via `ynh_config_add_nginx`, `ynh_config_add_systemd`, `ynh_config_add_logrotate`.
- `review.md` has been actioned — avoid reintroducing the issues it documents.
- **Versioning**: `version = "X.Y.Z~ynhN"` in `manifest.toml`. Bump the upstream version (`X.Y.Z`) when updating the app source; bump only `~ynhN` for packaging-only changes (config, scripts, manifest tweaks). Reset `~ynhN` to `~ynh1` when bumping the upstream version.
