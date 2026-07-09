# Evidencia Fase 7 — línea base operativa (captura 2026-07-08)

Pruebas ejecutadas contra la pila Docker local (author :4502, publish :4503,
dispatcher :8080).

## harden.sh — rotación de admin (ida)

```
>>> 1/4 Rotate admin password (publish first, then author)
    publish: admin password rotated
    author: admin password rotated
>>> 2/4 Update replication agent transport credentials on Author
    agent 'publish': transport updated, test SUCCEEDED
>>> 3/4 Disable default 'author' demo user (if present)
    http://localhost:4502: no default 'author' user found
    http://localhost:4503: no default 'author' user found
>>> 4/4 Smoke checks
    OK   author: new password authenticates as admin
    OK   author: old password no longer admin
    OK   publish: old password no longer admin
    OK   author: /crx/de not anonymous -> 401
    OK   author: /system/console not anonymous -> 401
    OK   publish: anonymous content read still works
>>> Hardening complete
```

## harden.sh — rotación inversa (prueba de reversibilidad)

Misma salida con `CURRENT_ADMIN_PASS`/`NEW_ADMIN_PASS` intercambiados: todos los
pasos OK, `Hardening complete`.

## Sanidad extremo a extremo tras el ciclo de rotación

```
activation: 200          (POST /bin/replicate.json en author)
dispatcher page: 200     (GET :8080/content/aemdemo/us/en.html)
```

## backup-packages.sh

```
>>> 1/4 Create/refresh package backups/content-backup (filter: /content/aemdemo)
    OK
>>> 2/4 Build package
    OK
>>> 3/4 Download to .../content-backup-20260708-220459.zip
    OK ( 16K, zip verified)
>>> 4/4 BACKUP_BUCKET not set — kept locally at .../content-backup-20260708-220459.zip
```

## configure-replication.sh — agentes por par (Fase 6, re-verificado)

Agente por defecto `publish` y agente adicional `publish1`: ambos con
`Replication test SUCCEEDED`.

## Estático

- `shellcheck` limpio sobre los 4 scripts (`install-aem.sh`, `harden.sh`,
  `backup-packages.sh`, `configure-replication.sh`).
- `actionlint` limpio sobre los 5 workflows.
- `terraform validate` correcto en dev/stage/prod tras integrar
  `install-aem.sh` en el user-data y el permiso de escritura de backups.
