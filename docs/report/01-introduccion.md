# 1. Introducción

## 1.1 Antecedentes

Adobe Experience Manager (AEM) es una de las plataformas de gestión de
experiencias digitales más extendidas en el segmento empresarial. Su
arquitectura clásica *on-premise* (AEM 6.5) se compone de al menos tres tipos
de nodo — **Author** (edición de contenido), **Publish** (servicio del
contenido publicado) y **Dispatcher** (caché, seguridad y balanceo delante de
cada Publish) — conectados por mecanismos de **replicación** e **invalidación
de caché** que deben configurarse de forma coherente entre sí.

En la práctica de la industria, la puesta en marcha de un proyecto AEM nuevo
sigue siendo un proceso mayormente artesanal: aprovisionar máquinas, instalar
Java y el *quickstart*, configurar *runmodes*, agentes de replicación y reglas
de filtrado del Dispatcher, crear los repositorios de código y los conductos de
integración continua. Este trabajo puede consumir días o semanas de personal
especializado, es difícil de reproducir de manera idéntica entre entornos
(desarrollo, *staging*, producción) y resulta propenso a errores de
configuración con impacto directo en seguridad y disponibilidad.

Paralelamente, la disciplina de **infraestructura como código** (IaC) y las
plataformas de **integración y entrega continuas** han madurado hasta el punto
de que el aprovisionamiento completo de una arquitectura de este tipo puede
expresarse como código versionado, revisado y ejecutado por un *pipeline*, con
autenticación federada hacia la nube y sin credenciales de larga duración.

## 1.2 Planteamiento del problema

No existe, como pieza pública y reutilizable, una plataforma que dada
únicamente una credencial de GitHub y una cuenta de nube: (a) cree el
repositorio del proyecto con su gobernanza (protección de ramas, entornos con
aprobaciones), (b) aprovisione la topología AEM completa por entornos a partir
de módulos parametrizados, (c) despliegue un sitio inicial extremo a extremo y
(d) deje configurada la operación básica (replicación, invalidación de caché,
endurecimiento de credenciales y copias de seguridad).

El problema abordado es, por tanto: **¿puede automatizarse por completo el
aprovisionamiento y el despliegue inicial de un proyecto AEM 6.5 sobre una nube
pública, de forma reproducible, gobernada y con una línea base de seguridad y
operación, usando exclusivamente herramientas estándar de IaC y CI/CD?**

## 1.3 Justificación

- **Relevancia industrial.** AEM 6.5 sigue ampliamente desplegado en modalidad
  *on-premise*/IaaS; la automatización de su ciclo de vida es un problema real
  de las organizaciones que lo operan.
- **Valor académico.** El proyecto integra, sobre un caso no trivial,
  competencias de infraestructura como código (Terraform), computación en la
  nube (AWS), CI/CD (GitHub Actions), seguridad (OIDC, mínimo privilegio,
  endurecimiento) y operación (backups, elasticidad).
- **Reproducibilidad y coste.** La estrategia «primero local» (paridad completa
  de la topología en Docker) permite validar el modelo sin gasto de nube y
  reduce el riesgo del despliegue real, que se acota a sesiones cortas de
  validación con destrucción posterior.
- **Extensibilidad.** El diseño modular y parametrizado deja planteada la
  extensión a otros proveedores (Azure/GCP) como trabajo futuro de tesis.

## 1.4 Objetivos

**Objetivo general.** Construir una plataforma que automatice el
aprovisionamiento de infraestructura y el despliegue inicial de proyectos AEM
6.5 sobre AWS mediante Terraform y GitHub Actions, validada primero sobre una
réplica local en Docker y después sobre la nube real.

**Objetivos específicos (medibles).**

1. **O1 — Bootstrap del repositorio:** con solo un token de GitHub, crear el
   repositorio, la protección de ramas, los entornos dev/stage/prod y las
   variables/secretos de Actions. *Métrica: un comando, < 2 minutos.*
2. **O2 — Aprovisionamiento de entornos:** `terraform apply` crea un entorno
   completo (red + Author + Publish + Dispatcher) desde módulos parametrizados.
   *Métrica: DEV, STAGE y PROD desde los mismos módulos, difiriendo solo en
   tfvars.*
3. **O3 — Elasticidad 1:1:** cambiar una variable (`publish_pair_count`)
   escala Publish y Dispatcher conjuntamente. *Métrica: demostración 1→2→1.*
4. **O4 — CI/CD:** GitHub Actions valida, planifica y aplica la infraestructura
   y despliega la aplicación por entorno con compuertas de aprobación.
   *Métrica: merge a main → despliegue automático a DEV; STAGE/PROD con
   aprobación.*
5. **O5 — Línea base operativa:** agentes de replicación configurados
   automáticamente; estrategia de backup implementada; línea base de seguridad
   aplicada. *Métrica: flush publish→dispatcher operativo; política de
   snapshots visible; contraseña de admin rotada.*
6. **O6 — Sitio demo:** un sitio generado con el arquetipo Maven de AEM
   desplegado extremo a extremo y accesible a través del Dispatcher. *Métrica:
   URL pública sirviendo páginas cacheadas.*
7. **O7 — Documentación:** informe escrito en español, presentación y
   diagramas que cubran diseño, implementación y resultados.

## 1.5 Alcance y limitaciones

El alcance se limita a **un proveedor de nube (AWS)** con diseño extensible, a
**AEM 6.5 LTS** (binarios licenciados, nunca incluidos en el repositorio) y a
un prototipo orientado a producción: subredes privadas, acceso por AWS SSM sin
SSH, autenticación GitHub→AWS por OIDC sin claves de larga duración, cifrado en
reposo y mínimo privilegio en los roles de instancia. Quedan explícitamente
fuera del alcance — y planteados como trabajo futuro — el multi-nube, la
recuperación ante desastres multi-región, el autoescalado reactivo por
métricas, la observabilidad completa y el CDN/WAF.
