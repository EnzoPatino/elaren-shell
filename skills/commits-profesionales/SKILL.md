---
name: commits-profesionales
description: Prepara commits claros y revisables en repositorios Git; úsala cuando se solicite ordenar, crear o publicar commits.
---

# Commits profesionales

Prepará un historial fácil de revisar y conservá el trabajo que ya existe en el árbol.

1. Antes de editar o preparar archivos, revisá `git status`, la rama y los commits locales pendientes. Leé las instrucciones del repositorio.
2. Inspeccioná los diffs y los archivos sin seguimiento. No incluyas secretos, artefactos generados ni cambios ajenos al pedido. No descartes ni reescribas cambios previos.
3. Agrupá cambios por propósito. Creá más de un commit cuando los grupos sean independientes; evitá dividir una unidad coherente solo para aumentar la cantidad de commits.
4. Prepará explícitamente los archivos de cada grupo y revisá el diff preparado antes de confirmar. No uses `git add -A` sin haber comprobado que todo el árbol pertenece al pedido.
5. Escribí mensajes breves, específicos y en el idioma usado por el proyecto. Empezá con un verbo en presente y describí el resultado; evitá mensajes vagos como «arreglos» o «actualizaciones». Usá el formato convencional del repositorio si ya existe.
6. No agregues cambios al último commit, no hagas amend ni reescribas historia salvo pedido explícito. No ejecutes pruebas o verificaciones ajenas al cambio.
7. Hacé push solo si la persona lo pidió o ya autorizó esa publicación. Antes, comprobá la rama, el remoto y los commits pendientes; publicá la rama actual al remoto configurado y reportá el resultado.

Al terminar, informá los identificadores y mensajes de los commits, qué se publicó y cualquier cambio local que haya quedado sin incluir.
