# Fase 8 — Validación en AWS real

## Estado

**COMPLETADA.** Tras la actualización de la cuenta al plan de pago, el ciclo
completo se ejecutó sobre AWS real: aprovisionamiento de DEV por el pipeline,
despliegue del sitio, configuración operativa, endurecimiento, backup,
demostración de elasticidad 1→2→1 y destrucción final verificada. La evidencia
completa está en `evidence/fase8-despliegue-aws.md`.

## Realizado y verificado

1. **Raíz global (`terraform/global`)** aplicada en la cuenta `599526349046`
   (us-east-1) mediante el workflow puntual `bootstrap-aws.yml`:
   - Proveedor OIDC de GitHub + roles `gha-aem-{dev,stage,prod}` con confianza
     restringida a `repo:neozilon/aem-infra-platform:environment:<env>` — las
     compuertas de revisores de stage/prod protegen también el acceso a AWS.
   - *Bucket* de estado remoto + tabla de bloqueo DynamoDB; *backends* S3
     activados en las tres raíces de entorno.
   - *Bucket* semilla privado con los binarios licenciados subidos (jar 394 MB,
     licencia, módulo dispatcher x86_64).
   - Presupuesto mensual de 50 USD con alertas al correo del titular.
2. **Cuota de vCPU** elevada de 5 a 16 (Service Quotas; aprobada en minutos).
3. **Cadena OIDC probada extremo a extremo** con un `plan` real de DEV desde el
   *runner*: autenticación federada, sincronización de binarios desde el
   *bucket* semilla, `init` contra el *backend* S3 y `plan` — funcionando.
   El primer `plan` real destapó un defecto (un `count` dependiente de un ARN
   calculado, prohibido por Terraform en tiempo de *plan*) que se corrigió con
   una bandera booleana.
4. **`apply` de DEV**: creó VPC, subredes, NAT, *endpoints*, *buckets*, IAM y
   ALB correctamente; **falló al lanzar las instancias EC2** con
   `InvalidParameterCombination: not eligible for Free Tier`.

## Bloqueo: plan gratuito de AWS

El modelo de cuentas actual de AWS distingue «Free plan» y «Paid plan». En el
plan gratuito **solo se pueden lanzar tipos de instancia elegibles para la capa
gratuita** (1 GB de RAM), con independencia de la cuota de vCPU. AEM requiere
`t3.xlarge` (16 GB) para el Author. La actualización al plan de pago requiere
acceso de facturación del titular y quedó pendiente.

## Disciplina de costes

Tras el bloqueo, el entorno parcial se **destruyó** vía el propio *pipeline*
(`deploy-infra`, acción `destroy`) y se verificó por API que no quedara ningún
recurso facturable (EC2, NAT, ALB, EIP, VPC: ninguno). Persisten solo los dos
*buckets* (estado y semilla, coste ≈ céntimos/mes), los roles IAM y la tabla de
bloqueo (gratuitos).

## Notas de entorno

Terraform no pudo ejecutarse contra AWS desde la máquina de desarrollo (las
peticiones del SDK de Go a las APIs de AWS no reciben respuesta, mientras que
curl/CLI de Python funcionan). Se adoptó como solución ejecutar **todo
Terraform-contra-AWS en los runners de GitHub**, lo cual además refuerza el
modelo del proyecto: la única vía de cambio de infraestructura es el pipeline.

## Reanudación (cuando la cuenta esté en plan de pago)

1. `deploy-infra` (dev, apply) — idempotente, retoma donde quedó.
2. Registrar `BINARIES_BUCKET`/`BACKUP_BUCKET` (outputs) y
   `secrets.AEM_ADMIN_PASSWORD`.
3. `deploy-app` → `configure` (con `harden`) → `backup`.
4. Demostración de elasticidad 1→2→1 (`publish_pair_count`).
5. Captura de evidencia y `destroy`.
