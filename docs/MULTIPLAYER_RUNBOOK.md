# Multiplayer runbook

## Resources (Cloudflare account wickedstudiosca@gmail.com, Workers Free plan)

| Resource | Name |
|---|---|
| Production Worker | `fate-lost-multiplayer` → https://fate-lost-multiplayer.wickedstudiosca.workers.dev |
| Staging Worker | `fate-lost-multiplayer-staging` → https://fate-lost-multiplayer-staging.wickedstudiosca.workers.dev |
| Durable Objects | `PartyRoom`, `RateLimiter` (SQLite-backed, per environment) |
| Local test env | `test` in `worker/wrangler.toml`, never deployed |

Everything is configured in `worker/wrangler.toml`. No dashboard configuration is needed, and there are no paid
products, KV, D1, R2 or queues. **No credential is in the app or in git.** Deployment uses `wrangler login`
(OAuth) on a developer machine; CI only runs tests.

## One-time setup

```bash
cd worker
npm ci
npx wrangler login      # opens a browser; then: npx wrangler whoami
```

## Test

```bash
npm run typecheck
npm run test:unit
npm test                # starts a local Worker in the `test` env, runs the integration suite
npm run test:staging    # the same suite against the deployed staging Worker (timing tests skip there)
```

The integration suite plays real WebSocket clients (2–4 players) through create, join, wrong password, full room,
ready, kick, close, start, relay, reconnect, host loss, expiry and the multi-run loop.

## Release

```bash
cd worker
npm test                              # 1. all green locally
npx wrangler deploy --env staging     # 2. staging
npm run test:staging                  # 3. against staging
curl https://fate-lost-multiplayer-staging.wickedstudiosca.workers.dev/health
npx wrangler deploy                   # 4. production (only after staging is healthy)
curl https://fate-lost-multiplayer.wickedstudiosca.workers.dev/health
```

A change that alters the protocol must ship the Worker **first** and remain compatible with the previous app
version, or bump `PROTOCOL_VERSION` (old apps then get "update the game" instead of undefined behaviour).

## Rollback

```bash
cd worker
npx wrangler deployments list                 # find the previous version id
npx wrangler rollback <version-id> --message "why"      # production
npx wrangler rollback <version-id> --env staging
```

Rolling back code never touches Durable Object storage, so parties in flight keep their state; a version that changed
what a `PartyRoom` stores must stay able to read the old shape. Migrations (`[[migrations]]`) are not rolled back: add
new ones, never edit `v1`. To take multiplayer down without a deploy, the app degrades by itself (the menu reports
"Could not reach the party service"); solo play never touches the network.

## Watching it

```bash
npx wrangler tail                      # production logs (observability is on)
npx wrangler tail --env staging
```

The service logs no room codes, names, passwords or credentials. Unexpected errors log only an error class.

## Free plan budget

A lobby that is idle costs nothing while it sleeps. In a run the host sends one batched message per tick (15/s whatever
the party size) and each guest sends 2–7 messages/s standing or walking, up to 20/s while changing direction or pressing
buttons. Incoming WebSocket messages count 1:20 toward the 100 000 daily request allowance, so a two-player run uses
about 60–100 request-equivalents per minute and a four-player run about 90–225 (the top end is everyone
steering constantly): roughly 7–25 hours of play per day for a family, in place of the 4–5 before batching. Outgoing messages are free.
Password hashing is 20 000 PBKDF2 rounds (`PBKDF2_ITERATIONS`), which fits the free CPU limit; lower it if a `1102`
"exceeded CPU" error ever shows in `tail`.

## Troubleshooting

| Symptom | Look at |
|---|---|
| "Could not reach the party service" | `/health`; the phone's connection; `wrangler tail` |
| Everyone gets `426` | app and service protocol versions differ; deploy the matching Worker or update the app |
| A room vanished | it expired (30 min with nobody connected, 2 h of lobby silence) or the host closed it |
| `429` on join | too many wrong codes/passwords from one address (10 minutes) or a locked room (1 minute) |
| Guest sees "Update Fate Lost" | `NetTables.contentVersion` differs between the two phones' builds |

## Known limitations

See `MULTIPLAYER_ARCHITECTURE.md`: the host is authoritative (and a single point of failure), progress is held on each
phone, there is no mid-run join, and the game has not yet been tried on real devices with real latency.
