# Fase 4 — Módulos de infraestructura en Terraform

## Objetivo

Cumplir el objetivo **O2** (aprovisionamiento por módulos parametrizados) y
sentar la base de **O3** (elasticidad 1:1). Se implementan seis módulos
reutilizables en `terraform/modules/`, validados sin coste de nube; el
despliegue real en AWS corresponde a la Fase 8.

## Módulos

- **`network`** — VPC, subredes públicas/privadas por zona de disponibilidad,
  *Internet Gateway*, NAT (único o por AZ), tablas de rutas, *endpoint* de S3
  (gateway) y *endpoints* de interfaz de SSM (Session Manager sin bastión).
- **`binaries`** — *bucket* S3 privado, versionado y cifrado, con subida del jar
  con licencia, el `license.properties`, el módulo de dispatcher y (opcional) el
  *service pack*. Política de *bucket* que exige TLS.
- **`author`** — instancia EC2 del Author (Amazon Linux 2023, IMDSv2), volúmenes
  EBS cifrados (raíz + datos), perfil IAM (SSM + lectura del *bucket* de
  binarios), *security group* y *user-data* que instala AEM desde S3 vía
  `systemd`.
- **`publish-pair`** — **un** Publish + **un** Dispatcher cableados 1:1: el
  Dispatcher solo renderiza su Publish emparejado y solo acepta *flush* desde
  esa IP. Se instancia con `count = publish_pair_count` (elasticidad).
- **`alb`** — *Application Load Balancer* público, *security group*, *target
  group* de Dispatchers (y opcional del Author por *host header*), *listeners*
  HTTP/HTTPS (redirección a HTTPS cuando hay certificado ACM).
- **`backup`** — política DLM de *snapshots* EBS diarios (selección por etiqueta
  `Backup`) y *bucket* S3 versionado para copias de paquetes de contenido.

## Decisiones de diseño

- **Elasticidad 1:1 (O3).** La raíz de entorno invoca `publish-pair` con
  `count = var.publish_pair_count`; una sola variable escala Publish y
  Dispatcher a la vez. El autoescalado por ASG queda como trabajo futuro.
- **Sin ciclo de módulos en el ALB.** Las *attachments* de los *target groups*
  se crean en la raíz de entorno, no en el módulo `alb`. Así `author` y
  `publish-pair` pueden depender del *security group* del ALB mientras el ALB
  depende de las IDs de instancia, sin ciclo.
- **Reutilización del Dispatcher de la Fase 2.** El *bootstrap* del Dispatcher
  escribe la misma configuración *deny-by-default* con la regla `/url` para
  *clientlibs* (corrección de la Fase 2), parametrizada con la IP del Publish
  emparejado.
- **Línea base de seguridad.** Subredes privadas, SSM en lugar de SSH, IMDSv2
  obligatorio, EBS/S3 cifrados, roles de instancia de mínimo privilegio y
  *bucket* de binarios solo por TLS.

## Validación

Cada módulo es válido de forma independiente
(`terraform init -backend=false && terraform validate`) y todo el árbol pasa
`terraform fmt -recursive -check`. Terraform 1.15, *provider* AWS `~> 5.60`.
`tflint`/`checkov` se ejecutarán en CI (Fase 6). No hay gasto de nube: la
validación no ejecuta `apply`.

## Resultado

Seis módulos parametrizados y validados que modelan un entorno AEM completo. La
Fase 5 los ensambla en las raíces `dev`/`stage`/`prod` (que difieren solo en
*tfvars*) y produce el primer `plan` integrado.
