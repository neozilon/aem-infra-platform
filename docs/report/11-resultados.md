# 11. Resultados y análisis

## 11.1 Cumplimiento de objetivos

| Obj. | Métrica comprometida | Resultado | Estado |
|---|---|---|---|
| **O1** | Repo + gobernanza desde un token, un comando, < 2 min | `bootstrap.sh` creó `neozilon/aem-infra-platform` con protección de `main`, entornos dev/stage/prod (stage/prod con revisor) y variables de Actions en ~1 min | ✅ |
| **O2** | DEV/STAGE/PROD desde los mismos módulos, difiriendo solo en tfvars | Raíces idénticas + módulo de composición (verificado por construcción y `validate`); DEV aprovisionado íntegro por el pipeline sobre AWS real | ✅ |
| **O3** | Escalado 1→2→1 cambiando una variable | Demostrado en AWS: `publish_pair_count` 1→2→1 vía push; par nuevo unido al ALB (2 targets *healthy*), replicación por par, **sin caída del par existente** durante ambas transiciones | ✅ |
| **O4** | merge→DEV automático; STAGE/PROD con aprobación; validación en PRs | `ci` obligatorio en `main` (checks requeridos); push a `terraform/**` aplicó DEV automáticamente; stage/prod exigen revisor y su rol AWS solo es asumible desde ese *environment* (OIDC) | ✅ |
| **O5** | Flush operativo; snapshots visibles; admin rotada | Flush publish→dispatcher configurado por par; política DLM `ENABLED`; backup Tier 2 en S3 versionado (13,7 KiB verificado); admin rotada y verificada por identidad (credencial antigua rechazada, sitio público intacto) | ✅ |
| **O6** | URL pública sirviendo páginas cacheadas | `http://aem-dev-alb-….elb.amazonaws.com/content/aemdemo/us/en.html` y sus clientlibs en 200 vía ALB→Dispatcher→Publish; segunda petición servida de caché | ✅ |
| **O7** | Informe + presentación + diagramas en español | Este documento, diagramas y evidencia por fase; presentación en Fase 10 | ✅ |

## 11.2 Tiempos medidos (ciclo completo en AWS)

| Paso | Duración observada |
|---|---|
| `terraform apply` del entorno (VPC→ALB→EC2) | ~7 min |
| Primer arranque de AEM (unpack + boot) | ~10–15 min |
| `deploy-app` (build Maven + SSM install en author+publish) | ~4 min |
| `configure` (replicación + flush por par) | ~1 min |
| Escalado +1 par (apply + boot + wire) | ~25 min |
| `destroy` completo | ~6 min |

Un entorno DEV validado de extremo a extremo queda disponible en **~30–45
minutos** desde un despacho del pipeline, sin intervención manual.

## 11.3 Coste real

La validación completa (entorno DEV ~1,7 h, con ~40 min a 2 pares) costó
**≈ 1,5–2 USD**, muy por debajo de la estimación conservadora del plan
(50–150 USD): la automatización reduce el coste porque reduce las horas de
infraestructura encendida. Tras la destrucción, el residuo permanente son dos
buckets S3 (estado y semilla de binarios), del orden de céntimos al mes.

## 11.4 Incidencias reales y su valor

La validación sobre AWS destapó cinco defectos que la paridad local no podía
revelar, todos corregidos en el código de la plataforma:

1. **Plan de cuenta AWS:** las cuentas «Free plan» solo lanzan instancias de
   capa gratuita, independientemente de la cuota de vCPU.
2. **Mínimo de volumen raíz:** los snapshots del AMI de Amazon Linux 2023
   exigen ≥ 30 GB.
3. **systemd vs `bin/start`:** el lanzador de AEM bifurca la JVM; la unidad
   pasó a ejecutar `java -nofork` en primer plano (el patrón ya probado del
   contenedor local).
4. **Carrera user-data / EBS:** el volumen de datos se adjunta después del
   arranque; la plantilla ahora espera al dispositivo.
5. **Orden endurecimiento/replicación** en el workflow cuando el secreto de la
   nueva contraseña ya existe: el endurecimiento se ejecuta primero.

El registro de estas incidencias (evidencia de la Fase 8) ilustra el argumento
central del trabajo: los entornos gestionados por código convierten fallos de
operación en cambios revisables y permanentes.

## 11.5 Amenazas a la validez

- STAGE y PROD no se mantuvieron encendidos simultáneamente (disciplina de
  coste); su equivalencia con DEV se sustenta en la identidad del código y en
  la validación estática, no en una ejecución prolongada.
- La demostración usa un sitio de arquetipo, no una carga de contenido real;
  el dimensionamiento de instancias no fue objeto de pruebas de carga.
- El escalado es explícito (variable + pipeline), no reactivo; el autoescalado
  queda fuera del alcance declarado.
