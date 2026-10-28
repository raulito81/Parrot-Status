---
name: release
description: Cierra una versión de Parrot Status: revisa README, CHANGELOG y versión del Info.plist en la rama de trabajo, pregunta las dudas, comprueba que compila, hace el commit, mezcla con main y pone la etiqueta. Úsala cuando el usuario pida cerrar, sacar o mezclar una versión o una rama.
argument-hint: "[X.Y.Z]"
disable-model-invocation: true
---

# Versión de Parrot Status

Argumentos: `$ARGUMENTS` (versión, opcional).

## 1. Situación de partida

- `git status`, `git branch --show-current`, `git tag --sort=-v:refname | head -3` y la versión actual:

  ```bash
  plutil -extract CFBundleShortVersionString raw "Parrot Status/Info.plist"
  plutil -extract CFBundleVersion raw "Parrot Status/Info.plist"
  ```

- **Los cambios tienen que estar en una rama**, no en `main`. Si hay cambios sin commit en `main`, crea antes la rama (`feat/…`, `fix/…`, `docs/…`) y llévalos a ella.
- `git fetch origin` y comprueba que `main` está al día con `origin/main` (`git rev-list --left-right --count main...origin/main`). Si `main` va por detrás, `git pull --ff-only` en `main`; si ha divergido, para y pregunta. `origin` es el fork personal; `upstream` (el original) no se toca.
- `git config user.email` tiene que ser `raulmaroto@gmail.com` (la global es la del trabajo). Si no, `git config user.name "Raul Maroto" && git config user.email raulmaroto@gmail.com`.
- Si hay cambios sin commit que no son de esta versión, para y pregunta.

## 2. Qué entra

- `git log --oneline main..HEAD` y los diffs (no solo los mensajes) para describir bien los cambios.
- **¿Lleva versión?** Sí si cambia la app (código, `MainMenu.xib`, `Info.plist`, permisos, proyecto). No si solo toca documentación interna (`CLAUDE.md`, `.claude/`): en ese caso pasa al paso 5 sin tocar versión ni CHANGELOG.
- Número: si no viene en los argumentos, propón el siguiente — **minor** para funcionalidad nueva, **patch** para correcciones — y confírmalo. Si la versión ya está puesta en la rama (por ejemplo, la 1.0.0 de `feat/macos-moderno`), confirma que es la que se cierra y no la subas otra vez.

## 3. Ficheros a revisar

1. **`Parrot Status/Info.plist`**: `CFBundleShortVersionString` = `X.Y.Z` y `CFBundleVersion` = build anterior + 1 (nunca se reinicia). Cámbialos con `sed` sobre la línea del valor: `plutil -replace` reordena todas las claves del fichero y ensucia el diff.
2. **`CHANGELOG.md`** (en inglés, como el resto del repo): entrada nueva encima de la anterior:

   ```markdown
   ## [X.Y.Z] - AAAA-MM-DD

   ### Added
   ### Changed
   ### Fixed
   ### Removed
   ```

   Solo las secciones con contenido, en ese orden, contado desde el punto de vista de quien usa la app y con datos concretos (opción del menú, versión de macOS…).
3. **`README.md`**: si el cambio afecta a algo que describe (requisitos, cómo compilar, instalación, opciones), actualízalo. Si no, no lo toques.
4. **`CLAUDE.md`**: si cambia algo de la arquitectura o de los requisitos de macOS que describe.

**Si hay cualquier duda** (número de versión, si algo merece entrada en el CHANGELOG, si el README debe cambiar), **pregunta antes de seguir**.

## 4. Comprobar

- Sigue `/check`: compilación sin avisos y comprobaciones del `.app` (la versión del `.app` tiene que ser la nueva). Si algo falla, para y enséñalo.
- Pregunta al usuario si ha probado la versión con los cascos (`/build`). Si cambia algo del Bluetooth o del protocolo y no lo ha probado, recomiéndalo antes de cerrar.

## 5. Commit, merge y etiqueta

Enseña al usuario el resumen de los cambios de versión (diff de `Info.plist`, `CHANGELOG.md` y `README.md`) y espera su visto bueno.

```bash
git add -A
git commit -m "X.Y.Z: resumen corto"         # o "docs: …" si no lleva versión
git switch main
git merge --no-ff <rama> -m "Merge branch '<rama>' into main"
git tag -a X.Y.Z -m "X.Y.Z"                    # solo si lleva versión; sin "v", como las anteriores
```

- Los mensajes de commit y merge llevan la línea `Co-Authored-By` que indique el sistema.
- Si no hay nada nuevo que commitear (todo estaba ya en la rama), sáltate el commit.
- Si el merge da conflictos, resuélvelos con el usuario; no a ciegas.
- Borra la rama mezclada solo si el usuario quiere (`git branch -d <rama>`).

## 6. Subir

- Pregunta antes de subir y, con su visto bueno, `git push origin main` y `git push origin X.Y.Z`. Comprueba al final que estás en `main` y que `git rev-list --left-right --count main...origin/main` da `0 0`.
- Si lleva versión, ofrece seguir con `/build zip` para instalarla y generar el zip.
