# Fase 7 — Línea base operativa (hardening, backups, instalación)

## Objetivo

Completar el objetivo **O5**: replicación configurada automáticamente (hecho en
Fases 2/6), estrategia de backup implementada y línea base de seguridad
aplicada, con la contraseña de `admin` rotada.

## Componentes

### `scripts/install-aem.sh` — instalador canónico

Instalador único para VMs (desempaqueta el quickstart con los *runmodes*
adecuados, crea la unidad `systemd`, arranca y espera la disponibilidad).
Los *user-data* de Terraform lo **embeben literalmente** (vía `templatefile`),
de modo que Author y Publish comparten una sola fuente de lógica de
instalación; además ambos módulos usan ahora una única plantilla compartida
(`terraform/modules/templates/aem-node-user-data.sh.tftpl`). Se añadió el
*runmode* de entorno (`dev`/`stage`/`prod`) junto al de rol.

### `scripts/harden.sh` — hardening (rotación de admin)

1. Rota la contraseña de `admin` en Publish y Author.
2. Actualiza las credenciales de transporte del agente de replicación y verifica
   con el *test* del agente (`succeeded`).
3. Deshabilita el usuario demo `author` si existe.
4. *Smoke checks*: la nueva contraseña autentica como `admin`, la antigua no,
   `/crx/de` y `/system/console` no son accesibles anónimamente, y la lectura
   anónima de contenido en Publish sigue funcionando (el sitio público no se
   rompe).

Es idempotente y reversible (intercambiando `CURRENT`/`NEW`), probado en ambos
sentidos contra la pila local.

### `scripts/backup-packages.sh` — backup Tier 2

Exporta un paquete de contenido vía la API del CRX Package Manager
(crear→filtrar→construir→descargar, con verificación del zip) y lo sube al
*bucket* S3 versionado cuando `BACKUP_BUCKET` está definido. El Tier 1
(*snapshots* EBS por DLM) ya estaba en el módulo `backup` de Terraform.

### Integración en la canalización

- `configure.yml` ganó la entrada opcional `harden` que ejecuta `harden.sh` por
  par vía SSM (idempotente: el Author se rota una vez).
- Nuevo `backup.yml`: exportación programada diaria (cron) + ejecución manual,
  por SSM en el Author. El rol de instancia del Author recibió el permiso
  mínimo `s3:PutObject` sobre `packages/*` del *bucket* de backups.

## Hallazgos técnicos relevantes (AEM 6.5 LTS)

1. **Cambio de contraseña:** los endpoints
   `currentuser.changepassword.html` (Granite) y `/system/userManager/...`
   (Sling) **no existen** en esta build: el *default POST servlet* de Sling
   responde 200/201 **creando nodos basura** en esas rutas — los códigos de
   estado no son fiables. El mecanismo correcto es un POST Sling plano de
   `rep:password` al nodo del usuario (Oak lo intercepta y lo *hashea*).
2. **Verificación de credenciales:** en Publish, unas credenciales incorrectas
   **no devuelven 401**: la petición cae a `anonymous` con HTTP 200. Toda
   comprobación de autenticación debe inspeccionar el **cuerpo** de
   `/libs/granite/security/currentuser.json` (`authorizableId`), no el código
   HTTP. `harden.sh` implementa ambas lecciones.

## Resultado

O5 completo a nivel de scripts y pipeline, verificado en local: rotación de
admin reversible con replicación funcionando tras la rotación, backup Tier 2
operativo y una única fuente de verdad para la instalación de AEM en VMs.
