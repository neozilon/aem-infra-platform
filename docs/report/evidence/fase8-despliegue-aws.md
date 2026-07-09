# Evidencia Fase 8 — despliegue real en AWS (captura 2026-07-09 11:44 CST)

## Sitio demo publicado (O6) — URL pública
```
200  http://aem-dev-alb-1194387710.us-east-1.elb.amazonaws.com/content/aemdemo/us/en.html
200  http://aem-dev-alb-1194387710.us-east-1.elb.amazonaws.com/etc.clientlibs/aemdemo/clientlibs/clientlib-base.css
200  http://aem-dev-alb-1194387710.us-east-1.elb.amazonaws.com/etc.clientlibs/aemdemo/clientlibs/clientlib-site.css
```

## Instancias (1 par inicial)
```
aem-dev-author	t3.xlarge	10.10.130.199
aem-dev-publish0	t3.large	10.10.136.199
aem-dev-dispatcher0	t3.small	10.10.128.187
```

## Pipeline (workflows del despliegue)
- deploy-infra (apply dev): success
- deploy-app (SSM install author+publish): success
- configure (replicación + flush por par): success

## Elasticidad 1→2 (O3) — captura tras el escalado

Cambio de una línea (`publish_pair_count = 2`) → push → apply automático.

```
Target group del ALB (dispatchers):
  i-078d5c0e9ca98fecb  healthy   (dispatcher0)
  i-0605898b8011c75ea  healthy   (dispatcher1)

Sitio por el ALB (balanceado): 200 200 200 200
Cadena del par 1 (dispatcher1 -> publish1, local): 200
Par 0 sirviendo DURANTE el escalado (sin caída): 200
Agentes en author: 'publish' (par 0) y 'publish1' (par 1), test SUCCEEDED
```

Instancias tras escalar: author, publish0/dispatcher0, publish1/dispatcher1.
