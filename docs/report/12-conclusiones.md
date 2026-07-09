# 12. Conclusiones y trabajo futuro

## 12.1 Conclusiones

1. **La automatización extremo a extremo de AEM 6.5 es viable con herramientas
   estándar.** Desde un token de GitHub hasta un sitio servido y cacheado por
   el Dispatcher en una URL pública, todos los pasos — repositorio y
   gobernanza, red, cómputo, cableado de replicación, despliegue de la
   aplicación, endurecimiento y copias de seguridad — quedaron expresados como
   código y ejecutados por el pipeline, sin pasos manuales. Los siete objetivos
   medibles se cumplieron.

2. **La estrategia «primero local» rinde más de lo que cuesta.** La paridad
   Docker permitió resolver a coste cero la parte del problema que es de AEM
   (filtros del Dispatcher, replicación, mecánica de contraseñas de 6.5) y
   reservar el gasto en nube para los defectos que solo la nube revela
   (permisos de cuenta, carreras de arranque, systemd). La validación final en
   AWS costó ~2 USD.

3. **La unidad de escalado 1:1 como módulo con `count` es un punto dulce**
   entre simplicidad y realismo: la elasticidad queda auditada (un cambio de
   variable en un commit), el aislamiento por par simplifica la seguridad
   (SG y `allowedClients` por par) y la demostración 1→2→1 transcurrió sin
   caída del servicio.

4. **La federación OIDC alinea gobernanza y nube.** Al restringir la confianza
   de cada rol IAM al *environment* de GitHub correspondiente, las aprobaciones
   humanas de stage/prod gobiernan también el acceso a AWS, y el sistema opera
   sin ninguna credencial de larga duración tras el bootstrap.

5. **El pipeline como única vía de cambio no es solo una buena práctica: fue
   la solución.** Cuando la estación de trabajo no pudo ejecutar Terraform
   contra AWS (anomalía de red del SDK), mover la ejecución a los runners no
   degradó el diseño — lo reforzó.

## 12.2 Lecciones aprendidas

- Las APIs reales desmienten la documentación con frecuencia: los endpoints
  «estándar» de cambio de contraseña no existen en 6.5 y el servlet por defecto
  **finge éxito**; en Publish las credenciales inválidas degradan a `anonymous`
  con HTTP 200. Toda verificación debe basarse en efectos observables (identidad
  en el cuerpo de la respuesta), no en códigos de estado.
- Los recursos con versionado (S3) y los mínimos de AMI introducen fricciones
  de destrucción/creación que conviene resolver en el código (`force_destroy`
  parametrizado, esperas de dispositivo) para que crear y destruir sean
  operaciones de un solo paso — condición necesaria de la disciplina de coste.
- `.gitignore` sin anclar, `count` sobre valores calculados, unidades systemd
  para procesos que bifurcan: errores pequeños con síntomas desproporcionados;
  la validación por capas (local → estática → plan real → apply real) los
  atrapó en el orden correcto.

## 12.3 Trabajo futuro (línea de tesis)

- **Multi-nube:** reimplementar los módulos `network/author/publish-pair/alb`
  sobre Azure/GCP manteniendo el módulo de composición y los workflows; medir
  qué fracción del diseño es portable.
- **Autoescalado reactivo:** sustituir el `count` por Auto Scaling Groups con
  alarmas (CloudWatch) y registro/desregistro automático de pares, incluyendo
  el cableado dinámico de replicación.
- **Mínimo privilegio en el pipeline:** descomponer el rol de administrador de
  los workflows en políticas por módulo generadas a partir del propio plan.
- **Observabilidad:** métricas y logs centralizados (CloudWatch/Grafana) con
  los indicadores propios de AEM (colas de replicación, ratio de caché del
  Dispatcher).
- **Resiliencia:** DR multi-región a partir de la estrategia de backups de dos
  niveles ya implantada; pruebas de restauración automatizadas.
- **Entrega de contenido:** CDN (CloudFront) y WAF delante del ALB; TLS
  extremo a extremo con ACM y dominio propio.
- **Ciclo de vida de AEM:** automatizar la instalación validada de service
  packs LTS según el runbook definido (bump de variable → DEV → promoción).
