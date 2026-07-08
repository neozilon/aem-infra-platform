# Fase 2 — Sitio demo y despliegue local extremo a extremo

## Objetivo

Validar el objetivo **O6** del plan: un sitio AEM generado con el Maven
archetype se compila, se despliega en Author y Publish, y queda accesible a
través del Dispatcher con la caché y la invalidación funcionando. Todo se hace
primero sobre la topología local en Docker (paridad con la nube) antes de
cualquier gasto en AWS.

## Componentes

- **Proyecto:** `demo-site/aemdemo`, generado con el AEM Project Archetype 56
  (grupo `aemdemo`, AEM 6.5, Java 21).
- **Topología local:** contenedores `aem-author` (:4502), `aem-publish` (:4503)
  y `aem-dispatcher` (:8080), definidos en `docker/docker-compose.yml`.

## Procedimiento ejecutado

1. **Compilación y despliegue en Author**
   `mvn clean install -PautoInstallSinglePackage` — construye los 11 módulos del
   reactor (core, ui.frontend, ui.apps, ui.content, all, etc.) e instala el
   paquete `aemdemo.all` en el Author. Requisito: `JAVA_HOME` apuntando a JDK 21.
2. **Despliegue en Publish**
   `mvn clean install -PautoInstallSinglePackagePublish` — mismo paquete sobre
   la instancia de Publish.
3. **Configuración de replicación**
   `scripts/configure-replication.sh` — configura el agente de replicación
   Author→Publish y crea el agente de *flush* Publish→Dispatcher (invalidación
   de caché). La prueba del agente reporta `succeeded`.
4. **Verificación por el Dispatcher**
   La página `/content/aemdemo/us/en.html` y todas las *clientlibs* devuelven
   HTTP 200 servidas a través del Dispatcher (:8080).

## Incidencia resuelta — filtro del Dispatcher para clientlibs

Al validar por el Dispatcher, la página HTML se servía (200) pero los archivos
CSS/JS de las *clientlibs* devolvían 404. El log del Dispatcher
(`logs/dispatcher.log`) mostraba las peticiones como `blocked`, es decir,
rechazadas por el filtro de seguridad *deny-by-default*, pese a existir una
regla de permiso `/etc.clientlibs/*`.

**Causa:** la regla usaba el selector `/path`. Con la directiva
`DispatcherUseProcessedURL On`, el Dispatcher descompone la URL y el punto en
`etc.clientlibs` altera la separación path/extensión, de modo que el *glob*
`/path "/etc.clientlibs/*"` nunca coincide.

**Solución:** cambiar las reglas de permiso a `/url` (que compara la URI de la
petición tal cual), convención que además usa el Dispatcher SDK de Adobe. Tras
el cambio y la reconstrucción de la imagen, todas las clientlibs se sirven 200.

Esta corrección quedó documentada como *gotcha* del entorno para no repetirla en
la fase de AWS, donde se reutiliza el mismo `publish-farm.any`.

## Evidencia

Ver `docs/report/evidence/fase2-despliegue-demo.md` (salidas de verificación:
códigos HTTP y resultado de la prueba de replicación).

## Resultado

Objetivo O6 cumplido en local: sitio demo desplegado extremo a extremo y
servido cacheado por el Dispatcher, con replicación e invalidación operativas.
El mismo procedimiento y la misma configuración de Dispatcher se reutilizarán
sin cambios en el despliegue sobre AWS (Fase 8).
