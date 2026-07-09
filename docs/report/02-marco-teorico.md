# 2. Marco teórico

## 2.1 Adobe Experience Manager y su arquitectura clásica

AEM es un gestor de experiencias digitales construido sobre un repositorio de
contenido JCR (Apache Jackrabbit Oak) y el framework web Apache Sling sobre
OSGi. En su modalidad *on-premise* (serie 6.x), una instalación productiva se
compone de:

- **Author:** instancia donde los editores crean y aprueban contenido.
- **Publish:** instancias que sirven el contenido publicado al público.
- **Dispatcher:** módulo de Apache httpd que actúa como caché de página,
  filtro de seguridad (*deny by default*) y punto de invalidación; la práctica
  recomendada es un Dispatcher por Publish.
- **Replicación:** los agentes de replicación del Author empujan contenido
  activado hacia cada Publish; a su vez, cada Publish dispara un agente de
  *flush* que invalida la caché de su Dispatcher.

Esta topología convierte el aprovisionamiento en un problema de **grafo de
dependencias**: el Dispatcher necesita conocer a su Publish; el agente de
flush, a su Dispatcher; el Author, a todos los Publish. Automatizarla exige
resolver el cableado en el momento del despliegue — un encaje natural para IaC.

La elección de **AEM 6.5 LTS** (frente a AEM as a Cloud Service) es deliberada:
en AEMaaCS Adobe gestiona la infraestructura y el problema de aprovisionamiento
desaparece; el valor académico de este trabajo reside precisamente en
automatizar lo que en 6.5 sigue siendo responsabilidad del cliente.

## 2.2 Infraestructura como código: Terraform

La infraestructura como código expresa los recursos (redes, cómputo,
almacenamiento, identidad) como ficheros declarativos versionados. Terraform
materializa el enfoque con tres piezas: un **lenguaje declarativo** (HCL), un
**grafo de dependencias** que calcula el orden de creación, y un **estado**
que reconcilia lo declarado con lo real (`plan` = diferencia, `apply` =
convergencia). Conceptos empleados en este proyecto:

- **Módulos** parametrizados y componibles: la unidad de reutilización. El
  patrón «módulo de composición + raíces finas por entorno» garantiza que los
  entornos difieren únicamente en datos (tfvars), no en código.
- **Estado remoto** con bloqueo (S3 + DynamoDB): requisito para ejecución
  concurrente segura desde un pipeline.
- **Proveedores**: el mismo motor gestiona AWS y GitHub, lo que permite tratar
  el propio repositorio y su gobernanza como infraestructura (Fase 3).

## 2.3 Integración y entrega continuas: GitHub Actions

GitHub Actions ejecuta *workflows* declarativos (YAML) ante eventos del
repositorio. Los conceptos relevantes:

- **Environments** con reglas de protección (revisores obligatorios, ramas
  permitidas): materializan las compuertas de aprobación para stage/prod.
- **Status checks obligatorios** en la protección de rama: ningún cambio llega
  a `main` sin pasar la validación (fmt/validate/lint/escáner IaC y build).
- **OIDC (OpenID Connect) hacia AWS:** el runner obtiene un token firmado por
  GitHub que AWS intercambia por credenciales temporales de un rol IAM cuya
  confianza está restringida al repositorio y al *environment* concretos. Se
  eliminan las claves de larga duración, y las aprobaciones de GitHub gobiernan
  también el acceso a la nube — un ejemplo de **federación de identidad**
  aplicada a CI/CD.

## 2.4 Seguridad de línea base en infraestructura en la nube

El diseño aplica principios estándar: subredes privadas para todos los nodos
AEM (solo el balanceador es público), acceso administrativo por **AWS Systems
Manager Session Manager** en lugar de SSH (sin bastión ni puertos de gestión
expuestos), **IMDSv2** obligatorio, cifrado en reposo (EBS/S3), **mínimo
privilegio** en roles de instancia (lectura del bucket de binarios; escritura
acotada al prefijo de backups), *buckets* privados con bloqueo de acceso
público y política TLS-only para los artefactos licenciados, y rotación de la
contraseña administrativa como paso operativo automatizado.

## 2.5 Estrategias de copia de seguridad

Se adopta un esquema de dos niveles habitual en cargas con estado: **Tier 1**,
instantáneas de volumen a nivel de infraestructura (EBS snapshots gestionados
por Data Lifecycle Manager, selección por etiquetas y retención por entorno); y
**Tier 2**, exportación lógica a nivel de aplicación (paquetes de contenido del
CRX Package Manager a un bucket S3 versionado), que permite restauraciones
selectivas de contenido independientes del ciclo de vida de las máquinas.

## 2.6 Trabajos relacionados

Adobe documenta arquitecturas de referencia para AEM sobre IaaS y publica
herramientas parciales (p. ej., recetas de instalación o el propio Dispatcher
SDK), y existen módulos comunitarios aislados para piezas del stack. La
aportación de este trabajo no es ninguna pieza individual, sino la
**integración extremo a extremo gobernada por pipeline** — desde el token de
GitHub hasta el sitio servido por el Dispatcher — con paridad local/nube
verificable y disciplina de costes explícita.
