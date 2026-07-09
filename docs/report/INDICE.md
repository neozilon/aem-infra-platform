# Informe final — estructura maestra

**Título:** Plataforma automatizada de aprovisionamiento de infraestructura y
despliegue inicial de proyectos AEM mediante Terraform y GitHub Actions
**Autor:** Fede Arriola · **Idioma:** español (código y repositorio en inglés)

Cada capítulo se redacta como Markdown en este directorio y se ensambla al
documento final (.docx) en la Fase 10. Estado: ✅ borrador listo · 🔶 parcial ·
⬜ pendiente.

| # | Capítulo | Fuente / archivo | Estado |
|---|---|---|---|
| 1 | Introducción: antecedentes, problema, justificación, objetivos | `01-introduccion.md` | ✅ |
| 2 | Marco teórico | `02-marco-teorico.md` | ⬜ |
| 3 | Arquitectura de la solución | `03-arquitectura.md` (base: PLAN §3) | ⬜ |
| 4 | Implementación — pila local y sitio demo | `fase2-sitio-demo.md` | ✅ |
| 5 | Implementación — bootstrap del repositorio | `fase3-bootstrap-repositorio.md` | ✅ |
| 6 | Implementación — módulos de infraestructura | `fase4-modulos-terraform.md` | ✅ |
| 7 | Implementación — entornos | `fase5-entornos.md` | ✅ |
| 8 | Implementación — CI/CD | `fase6-cicd.md` | ✅ |
| 9 | Implementación — línea base operativa | `fase7-linea-base-operativa.md` | ✅ |
| 10 | Pruebas y validación en AWS | `fase8-validacion-aws.md` (+ evidencia pendiente del despliegue) | 🔶 |
| 11 | Resultados y análisis de objetivos O1–O7 | `11-resultados.md` | ⬜ |
| 12 | Conclusiones y trabajo futuro | `12-conclusiones.md` | ⬜ |
| — | Anexos: evidencia | `evidence/` | 🔶 |

## Mapa objetivos → evidencia

| Objetivo | Demostración | Evidencia |
|---|---|---|
| O1 repo bootstrap | Fase 3 ejecutada (repo real creado < 2 min) | fase3 + capturas GitHub |
| O2 aprovisionamiento por módulos | Fases 4–5 validadas; apply DEV (Fase 8) | fase8 + outputs |
| O3 elasticidad 1:1 | demo 1→2→1 (Fase 8, pendiente) | pendiente |
| O4 CI/CD con compuertas | Fase 6 en producción (checks obligatorios, gates) | evidence/fase6-cicd.md |
| O5 línea base operativa | Fase 7 probada en local; harden/backup en AWS (pendiente) | evidence/fase7-ops.md |
| O6 sitio demo por Dispatcher | Fase 2 local; URL pública (Fase 8, pendiente) | evidence/fase2 |
| O7 documentación | este informe + diagramas + runbooks | docs/ |
