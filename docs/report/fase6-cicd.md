# Fase 6 — Canalizaciones CI/CD (GitHub Actions)

## Objetivo

Cumplir el objetivo **O4**: validación automática, *plan/apply* de
infraestructura y despliegue de la aplicación AEM por entorno con compuertas de
aprobación. Se implementan los cuatro *workflows* previstos en el plan (§3.2).

## Workflows

### `ci.yml` — validación estática (en cada PR y *push* a `main`)

- `terraform fmt -recursive -check` y `terraform validate` de todas las raíces
  (`bootstrap`, `envs/dev|stage|prod`).
- **tflint** (reglas Terraform) y **checkov** (escaneo de seguridad IaC, en modo
  informativo para el alcance de prototipo).
- Compilación Maven del sitio demo (`mvn clean package`), con Java 21.

Los nombres de *job* (`ci-terraform`, `ci-app`) se configuraron como ***status
checks* obligatorios** en la protección de `main` (vía `bootstrap/`): ningún PR
puede fusionarse sin CI en verde.

### `deploy-infra.yml` — infraestructura por entorno

- *Push* a `main` que toque `terraform/**` → `plan` + `apply` **automático en
  DEV**; `stage`/`prod` (y `destroy`) solo por ejecución manual, **bloqueada por
  las reglas de protección del entorno** (revisor requerido) creadas en la
  Fase 3 — la aprobación con compuertas de O4.
- Autenticación **GitHub→AWS por OIDC** (rol IAM por entorno en la variable
  `AWS_ROLE_ARN`); sin credenciales de larga vida.
- Los binarios licenciados nunca están en git: el *pipeline* los sincroniza
  desde un *bucket* semilla privado (`BINARIES_SEED_BUCKET`) antes del `plan`.
- Hasta que la Fase 8 configure la cuenta de AWS, los *jobs* terminan en verde
  con un aviso (`::notice`) en lugar de fallar: la canalización queda operativa
  pero inerte.

### `deploy-app.yml` — aplicación AEM

Compila los paquetes de contenido y los instala en Author y Publish. Como las
instancias están en subredes privadas, la instalación va por **SSM
send-command**: cada nodo descarga el paquete del *bucket* de binarios del
entorno (su rol de instancia ya tiene lectura) y lo instala contra el CRX
Package Manager en `localhost`. *Push* que toque `demo-site/**` → DEV
automático; `stage`/`prod` manual con compuerta.

### `configure.yml` — configuración operativa (O5)

Ejecuta `scripts/configure-replication.sh` **en el Author** vía SSM, una vez por
par Publish:Dispatcher: agente de replicación `publish`/`publishN` hacia cada
Publish y agente de *flush* de cada Publish hacia su Dispatcher emparejado. El
script se descarga del propio repositorio (público) en el commit exacto en
ejecución.

## Correcciones derivadas del diseño

Al trazar el flujo de *flush* se detectó que el *security group* del Dispatcher
solo admitía tráfico del ALB: la invalidación de caché desde Publish habría sido
bloqueada en AWS (en local funcionaba por la red plana de Docker). Se añadió la
regla Publish→Dispatcher:80 y, como ahora los dos SG se referencian mutuamente,
se reestructuraron como recursos de regla independientes
(`aws_vpc_security_group_ingress_rule`) para evitar el ciclo de dependencias.

`configure-replication.sh` se parametrizó con `AGENT_NAME` (creación del agente
si no existe) para soportar N pares, y se re-verificó contra la pila Docker
local (agentes `publish` y `publish1`, ambos con *test* `succeeded`).

## Validación

- `actionlint` (incluye shellcheck de los *scripts* embebidos): sin hallazgos.
- Raíces Terraform re-validadas tras el cambio de SG: `Success`.
- Primer *run* real de `ci.yml` en GitHub Actions: verde (ver evidencia).

## Resultado

Canalización completa: CI obligatoria en PRs, despliegue de infraestructura y
aplicación por entorno con OIDC y compuertas de aprobación en stage/prod, y
configuración operativa automatizada. Lista para activarse con la cuenta de AWS
en la Fase 8.
