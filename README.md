# Toolkit Técnico

Repositorio privado centralizado con herramientas de diagnóstico, scripts de automatización y configuraciones de sistema (Windows).

## Estrategia de Despliegue
Diseñado para ser descargado en equipos de terceros mediante un script lanzador de PowerShell ("One-Liner"). 
* Utiliza un Token de Acceso Personal (PAT) de solo lectura.
* Se descarga y extrae en entorno temporal.
* Borra rastros de historial de comandos y caché al finalizar.