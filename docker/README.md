# Local AEM stack (Phase 1)

Mirrors one cloud environment on your laptop: **Author** (4502), **Publish** (4503), **Dispatcher** (8080 → Apache 2.4 + module 4.3.8).

## Prerequisites

- Docker Desktop with **≥ 12 GB RAM** allocated (Settings → Resources). AEM Author alone needs ~4 GB heap.
- `binaries/` populated: `cq-quickstart-6.6.0.jar`, `license.properties`, both `…4.3.8.tar.gz` dispatcher tarballs.

## Run

```bash
# from the repo root
docker compose -f docker/docker-compose.yml up -d --build
```

First start takes **10–15 min per AEM node** (repository initialization). Follow progress:

```bash
docker logs -f aem-author        # ready when "startup completed" appears
```

| Service | URL | Credentials |
|---|---|---|
| Author | http://localhost:4502 | admin / admin (rotated in Phase 7) |
| Publish | http://localhost:4503 | admin / admin |
| Dispatcher | http://localhost:8080 | — (serves cached Publish content) |

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4502/libs/granite/core/content/login.html   # 200
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/content.html                            # 404 until demo site deployed — but dispatcher log shows the request
docker exec aem-dispatcher cat /usr/local/apache2/logs/dispatcher.log | tail
```

## Notes

- The repository (`crx-quickstart`) persists in named volumes; `docker compose down -v` wipes it for a clean start.
- The dispatcher farm (`docker/dispatcher/conf/publish-farm.any`) is the same deny-by-default model used on AWS; `${PUBLISH_HOST}`/`${PUBLISH_PORT}` are env-substituted, which is what lets the identical file serve any environment.
- Apple Silicon: images build natively (aarch64 dispatcher module); no emulation.
