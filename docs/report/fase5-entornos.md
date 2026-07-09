# Fase 5 — Entornos dev/stage/prod

## Objetivo

Completar el objetivo **O2**: aprovisionar entornos completos (DEV, STAGE, PROD)
a partir de los mismos módulos, difiriendo **solo en *tfvars***. Sienta también
la base de **O3** (elasticidad 1:1) al exponer `publish_pair_count` por entorno.

## Diseño: módulo de composición + raíces finas

Para evitar duplicar la lógica de cableado en tres directorios (con el riesgo de
divergencia), se introduce un módulo de composición
`terraform/modules/aem-environment` que instancia y conecta los seis módulos de
la Fase 4 y crea las *attachments* de los *target groups* del ALB.

Cada raíz de entorno (`terraform/envs/{dev,stage,prod}`) es un envoltorio fino
con archivos `.tf` **idénticos** (`providers.tf`, `variables.tf`, `main.tf`,
`outputs.tf`) que solo delega en el módulo de composición. La única diferencia
entre entornos es el archivo `<env>.tfvars`.

## Parámetros por entorno

| Parámetro | DEV | STAGE | PROD |
|---|---|---|---|
| `publish_pair_count` | 1 | 1 | **2** |
| `single_nat_gateway` | sí | sí | **no (NAT por AZ)** |
| `backup_retention_count` | 3 | 7 | **30** |
| `snapshot_interval_hours` | 24 | 24 | 12 |
| `vpc_cidr` | 10.10/16 | 10.20/16 | 10.30/16 |

PROD demuestra el escalado 1:1 (dos pares Publish+Dispatcher) y usa NAT por AZ
para alta disponibilidad; los tamaños de instancia son idénticos para acotar el
coste del prototipo (ajustables por *tfvars*).

## Estado de Terraform

Por decisión de la Fase 5, el *state* es **local** por ahora, lo que permite
construir y validar las raíces sin acceso a la nube. El *backend* remoto
(S3 + tabla de bloqueo DynamoDB) está escrito y **comentado** en cada
`providers.tf`; se activará en la Fase 8, al existir la cuenta de AWS y el
*bucket* de estado.

## Validación

`terraform fmt -recursive -check` limpio y `terraform validate` correcto en el
módulo de composición y en las tres raíces:

```
envs/dev   -> Success! The configuration is valid.
envs/stage -> Success! The configuration is valid.
envs/prod  -> Success! The configuration is valid.
```

No se ejecuta `plan`/`apply` (requiere credenciales de AWS y los binarios
locales); corresponde a la Fase 8.

## Resultado

Tres entornos definidos por una sola base de código parametrizada. Cambiar
`publish_pair_count` en un *tfvars* escala el par Publish:Dispatcher del entorno
(demostración 1→2→1 prevista en la Fase 8). Objetivo O2 cumplido a nivel de
definición y validación.
