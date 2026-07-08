# Fase 3 — Bootstrap del repositorio desde un token

## Objetivo

Cumplir el objetivo **O1**: a partir únicamente de un token de GitHub, la
plataforma crea el repositorio del proyecto, la protección de ramas, los
entornos de despliegue (`dev`/`stage`/`prod`) y los *secrets*/variables de
Actions, en un solo comando y en menos de 2 minutos.

## Enfoque

Se implementa como una raíz de Terraform independiente en `bootstrap/`, que usa
exclusivamente el *provider* `integrations/github` (`~> 6.2`). No requiere
credenciales de nube: es el primer paso de la cadena de aprovisionamiento y solo
depende del token. Un script envoltorio `bootstrap.sh` ofrece la ejecución de un
solo comando.

## Recursos creados

- **Repositorio** (`github_repository`): `aem-infra-platform`, con *merge* por
  *squash*/*rebase*, borrado de rama al fusionar y alertas de vulnerabilidades
  (Dependabot).
- **Protección de la rama `main`** (`github_branch_protection`): revisión de PR
  obligatoria y, opcionalmente, *status checks* requeridos (se activarán con el
  nombre del *job* de CI en la Fase 6).
- **Entornos de despliegue** (`github_repository_environment`) `dev`, `stage`,
  `prod`. `stage` y `prod` quedan **protegidos**: exigen revisores aprobadores y
  solo despliegan desde ramas protegidas, materializando la aprobación con
  compuertas del objetivo O4. `dev` queda abierto para el auto-despliegue en
  *merge* a `main`.
- **Variables de Actions** (`github_actions_variable`): se siembran las versiones
  fijadas (`AEM_VERSION`, `DISPATCHER_VERSION`, `JAVA_VERSION`, `AWS_REGION`…),
  de modo que los *pipelines* las lean de forma centralizada (PLAN §7b).
- **Variables y *secrets* por entorno** (opcionales): p. ej. los ARN de rol de
  AWS para OIDC se añadirán aquí cuando exista la cuenta de AWS (Fase 4+).

## Manejo del token (seguridad)

El token se lee de la variable de entorno `GITHUB_TOKEN` (o se solicita por
consola sin eco) y se pasa a Terraform como `TF_VAR_github_token`. Nunca se
escribe en disco ni se incluye en `terraform.tfvars`. El estado de Terraform y
los `*.tfvars.secret` están excluidos por `.gitignore`.

## Validación realizada

- `terraform fmt -check` — sin diferencias.
- `terraform init` — *provider* GitHub 6.x descargado y bloqueado en
  `.terraform.lock.hcl`.
- `terraform validate` — **Success! The configuration is valid.**
- Pruebas del envoltorio: `bootstrap.sh -h` y validación de argumentos
  (falta de *owner*) correctas.

Queda **pendiente la ejecución real** contra GitHub, que requiere el token de
Fede; la infraestructura de código está completa y validada.

## Incidencias y decisiones técnicas

- **Instalación de Terraform:** la fórmula `terraform` de Homebrew ya no existe
  (recambio de licencia BSL de HashiCorp). Se usa el *tap* oficial
  `hashicorp/tap` (versión 1.15.7).
- **`for_each` sobre valores sensibles:** Terraform prohíbe iterar una variable
  `sensitive` porque las claves de instancia quedarían expuestas. Se resuelve
  envolviendo los *nombres* de *secret* (que no son sensibles) con
  `nonsensitive()` y obteniendo cada valor desde la variable dentro del recurso.
- **Plan gratuito de GitHub:** la protección de ramas y los entornos en
  repositorios **privados** exigen un plan de pago. Como el repositorio no
  contiene binarios licenciados (están *gitignored*), puede crearse **público**
  en plan gratuito; la visibilidad es una variable (`repository_visibility`).

## Resultado

Objetivo O1 implementado y validado a nivel de código: un único comando
(`bootstrap.sh`) crea repositorio, gobernanza y entornos desde el token. La
ejecución contra la cuenta real de GitHub se realizará al disponer del token.
