# 3. Arquitectura de la solución

## 3.1 Visión general

La plataforma se organiza en tres planos:

1. **Plano de gobernanza (GitHub).** El repositorio, su protección de ramas,
   los entornos con aprobaciones y las variables/secretos de Actions se crean
   por Terraform (provider de GitHub) a partir de un único token — objetivo O1.
2. **Plano de infraestructura (AWS).** Módulos Terraform aprovisionan, por
   entorno, la red y la topología AEM completa; el estado vive en S3 con
   bloqueo en DynamoDB; los binarios licenciados se distribuyen desde un
   bucket privado — objetivos O2/O3.
3. **Plano de entrega (GitHub Actions).** Cinco workflows (validación,
   infraestructura, aplicación, configuración, backup) ejecutan todo cambio;
   la autenticación hacia AWS es federada por OIDC y las aprobaciones de
   entorno gobiernan stage/prod — objetivos O4/O5/O6.

## 3.2 Topología por entorno

Cada entorno (DEV = STAGE = PROD, parametrizados) despliega en su propia VPC:

```
                        ┌────────────────────────── VPC (por entorno) ──────────────────────────┐
                        │  subredes públicas: ALB, NAT                                           │
 Internet ──► ALB ──►   │  subredes privadas:                                                    │
 (HTTP/S)               │   ┌──────────┐      ┌──────────────── grupo de pares ────────────────┐ │
                        │   │  AUTHOR  │      │  ┌────────────┐  1:1   ┌────────────────────┐  │ │
   Autores ──► regla    │   │  :4502   │─repl─┼─►│ PUBLISH n  │◄───────│ DISPATCHER n       │◄─┼─┼── ALB
   de host en el ALB    │   └──────────┘      │  │ :4503      │─flush─►│ httpd+módulo :80   │  │ │
                        │                     │  └────────────┘        └────────────────────┘  │ │
                        │                     │            × publish_pair_count                │ │
                        │                     └────────────────────────────────────────────────┘ │
                        │  SSM Session Manager (sin bastión) · S3 (binarios/backups) · DLM       │
                        └────────────────────────────────────────────────────────────────────────┘
```

Decisiones estructurales:

- **Par 1:1 Publish:Dispatcher como unidad de escalado.** El módulo
  `publish-pair` encapsula un Publish y un Dispatcher cableados entre sí (el
  Dispatcher renderiza solo su Publish; el flush del Publish solo alcanza a su
  Dispatcher, restringido por security groups y por `allowedClients`). La raíz
  de entorno lo instancia con `count = publish_pair_count`: **la elasticidad es
  un cambio de variable auditado por el pipeline** (O3). El autoescalado
  reactivo (ASG) queda como trabajo futuro.
- **Author único por entorno** (estatal, dimensionado en memoria), alcanzable
  solo mediante regla de *host* en el ALB.
- **Acceso administrativo sin SSH:** AWS SSM Session Manager; los despliegues
  de aplicación y la configuración operativa llegan a las subredes privadas por
  `ssm send-command`.
- **Binarios licenciados fuera de git:** bucket S3 privado por entorno
  (módulo `binaries`), poblado desde un bucket semilla; las instancias los
  descargan en el arranque mediante su rol IAM.

## 3.3 Estructura de módulos Terraform

```
terraform/
├── global/            # una vez por cuenta: OIDC GitHub, roles por entorno,
│                      # bucket de estado + tabla de bloqueo, bucket semilla, presupuesto
├── modules/
│   ├── network        # VPC, subredes, NAT, endpoints S3/SSM
│   ├── binaries       # bucket privado + subida de artefactos licenciados
│   ├── author         # EC2 + EBS + IAM + user-data (instalador embebido)
│   ├── publish-pair   # 1 Publish + 1 Dispatcher, cableados 1:1
│   ├── alb            # ALB, target groups, listeners
│   ├── backup         # política DLM (Tier 1) + bucket de paquetes (Tier 2)
│   └── aem-environment# módulo de COMPOSICIÓN: cablea los seis anteriores
└── envs/{dev,stage,prod}  # raíces finas idénticas; solo difieren los tfvars
```

Dos patrones merecen mención:

- **Composición + raíces finas.** Toda la lógica de cableado vive una sola vez
  en `aem-environment`; las tres raíces son envoltorios idénticos. La promesa
  «los entornos difieren solo en tfvars» (O2) se cumple por construcción.
- **Attachments fuera del módulo ALB.** Author y publish-pair dependen del
  security group del ALB, y el ALB depende de las instancias como *targets*;
  crear las `target_group_attachments` en el módulo de composición rompe el
  ciclo de dependencias sin sacrificar la cohesión de cada módulo.
- **Instalador único.** El script canónico `install-aem.sh` se embebe
  literalmente en el user-data de Author y Publish (una sola plantilla
  compartida): la lógica de instalación tiene una única fuente de verdad,
  reutilizada conceptualmente por la paridad local.

## 3.4 Cadena de identidad y aprobaciones

```
push/dispatch ─► GitHub Actions (environment: dev|stage|prod)
                    │  (stage/prod: aprobación de revisor obligatoria)
                    ▼
        token OIDC firmado por GitHub
                    ▼
   AWS IAM role gha-aem-<env>  (trust: repo + environment EXACTOS)
                    ▼
     credenciales temporales STS → terraform / aws cli
```

La condición de confianza del rol (`sub = repo:<owner>/<repo>:environment:<env>`)
hace que **la única vía de obtener credenciales de AWS sea un job aprobado del
pipeline**: las compuertas de GitHub gobiernan también la nube. No existe
ninguna clave de larga duración tras el bootstrap (la única, humana, se usa una
vez para crear este plano y se elimina).

## 3.5 Paridad local

`docker/docker-compose.yml` reproduce la topología lógica completa en la
máquina de desarrollo (author :4502, publish :4503, dispatcher :8080) con los
mismos binarios, la misma configuración de farm del Dispatcher (misma regla
`/url` para clientlibs, mismos parámetros vía variables de entorno) y los
mismos scripts operativos. Todo comportamiento se valida primero en local a
coste cero; la nube se reserva para la validación final — lo que además redujo
el riesgo real del proyecto (las incidencias de las Fases 2 y 7 se detectaron y
resolvieron sin gasto).

## 3.6 Gestión de versiones y actualizaciones

Todas las versiones (AEM, service pack, Dispatcher, Java) están fijadas como
variables; una actualización es un cambio de variable que recorre el pipeline
(plan → aprobación → apply), nunca un parche manual. El caso «service pack»
está documentado como runbook y diferenciado por tier: reemplazo inmutable de
los pares Publish/Dispatcher, instalación en caliente sobre el Author estatal.
