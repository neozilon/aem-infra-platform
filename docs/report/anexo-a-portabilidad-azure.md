# Anexo A — Análisis de portabilidad a Microsoft Azure

Este anexo concreta la línea de trabajo futuro «multi-nube» (cap. 12) con un
análisis técnico de qué fracción de la plataforma es neutra al proveedor y qué
requeriría reimplementación para soportar Azure, partiendo del estado actual.

## A.1 Principio de diseño que habilita el porte

La plataforma separa tres planos con acoplamientos débiles:

1. **Conocimiento de AEM** (scripts de instalación, replicación, hardening,
   backup; configuración del Dispatcher): habla HTTP con AEM y bash con el SO —
   **no sabe en qué nube corre**.
2. **Orquestación** (workflows, módulo de composición, portal): conoce la
   *forma* de la topología (un Author, N pares, un balanceador) pero delega los
   recursos concretos en los módulos.
3. **Recursos de proveedor** (módulos Terraform network/author/publish-pair/
   alb/binaries/backup): lo único intrínsecamente AWS.

El coste del porte se concentra en el plano 3; los planos 1–2 —donde se invirtió
la mayor parte del esfuerzo de depuración del proyecto— se conservan.

## A.2 Matriz de portabilidad

| Capa | Reutilización estimada | Equivalencia en Azure |
|---|---|---|
| Scripts operativos (`install-aem.sh`, `configure-replication.sh`, `harden.sh`, `backup-packages.sh`) | ~95 % | Sin cambios funcionales (HTTP a AEM + bash); solo cambia cómo se invocan remotamente |
| Configuración del Dispatcher (farm, filtros `/url`, flush 1:1) | 100 % | Idéntica — es configuración de Apache |
| Módulo de composición + raíces por entorno + tfvars | ~85 % | Mismo patrón; selecciona `modules/azure/*` en lugar de `modules/aws/*` |
| Workflows CI/CD | ~70 % | `azure/login` con **federación OIDC de GitHub a Entra ID** (mismo modelo sin claves); `az` CLI en lugar de `aws` |
| Portal | ~90 % | Cambiar las llamadas `aws` por `az`; el resto es API de GitHub |
| Módulos de recursos | **reescritura interna, interfaz conservada** | Ver tabla A.3 |

## A.3 Correspondencia de recursos

| AWS (actual) | Azure (equivalente) | Observaciones |
|---|---|---|
| VPC + subredes + NAT GW | VNet + subnets + NAT Gateway | Correspondencia directa |
| EC2 + user-data | Virtual Machines + cloud-init (`custom_data`) | El mismo shell de arranque funciona (cloud-init) |
| ALB (target groups, reglas por host) | Application Gateway | AppGW aporta también WAF opcional |
| S3 (binarios, backups) | Blob Storage (contenedores privados) | Versionado y cifrado equivalentes |
| SSM Session Manager / send-command | Azure **Run Command** / Bastion | Run Command es funcionalmente análogo aunque más lento; punto de mayor fricción del porte |
| IAM instance profile | Managed Identity | Modelo más simple en Azure |
| OIDC provider + roles por entorno | Workload Identity Federation (Entra ID) + app registrations | GitHub soporta ambos de forma nativa |
| DLM (snapshots EBS) | Azure Backup / snapshots de Managed Disks | Política programada equivalente |
| Backend S3 + DynamoDB | Backend `azurerm` (Storage Account con *blob lease*) | Azure no necesita tabla de bloqueo aparte |
| Cuotas de vCPU (Service Quotas) | vCPU quotas por familia y región | Mismo riesgo operativo: verificar antes del primer despliegue |

## A.4 Estructura propuesta

```
terraform/
├── modules/
│   ├── aem-environment/        # composición (se conserva)
│   ├── aws/{network,author,publish-pair,alb,binaries,backup}
│   └── azure/{network,author,publish-pair,appgw,binaries,backup}  ← nuevo
└── envs/{dev,stage,prod}       # ganan la variable cloud = "aws" | "azure"
```

Las **interfaces** (variables/salidas) de los módulos se congelan como contrato:
el módulo de composición no cambia, y la métrica de éxito del porte es
justamente «cero cambios fuera de `modules/azure/`».

## A.5 Esfuerzo estimado y plan de validación

Estimación: **30–40 % del esfuerzo Terraform original** (4–6 sesiones de
trabajo) hasta la paridad de DEV, porque todo el conocimiento específico de AEM
ya está resuelto y probado. Plan de validación idéntico al de la Fase 8:
`provision` de DEV en Azure → sitio por el Application Gateway → demo de
elasticidad → captura de evidencia → destrucción; y como resultado empírico
para la tesis, medir la fracción de líneas/módulos tocados frente a los
conservados.

## A.6 Riesgos específicos del porte

- **Run Command** tiene mayor latencia y peores límites de salida que SSM;
  puede requerir reescribir la espera de disponibilidad de AEM.
- Tiempos de aprovisionamiento de Application Gateway (~10–15 min) alargan el
  ciclo crear/destruir.
- Los *builds* del módulo Dispatcher son x86_64 Linux: elegir series de VM
  Intel/AMD (D/E-series), no ARM (Ampere).
