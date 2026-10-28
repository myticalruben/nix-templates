# Proyecto Python con Nix

```bash
nix develop                    # entrar al entorno (crea y activa .venv)
nix develop -c ruff check .    # comando suelto, sin entrar
nix flake check                # los checks del entorno
```

## Qué pone Nix y qué no

| Pieza | La da |
|---|---|
| Intérprete CPython (versión fijada) | Nix |
| `uv` (resolución e instalación rápida) | Nix |
| `ruff` (linter, formateador y LSP) | Nix |
| Tus dependencias | `.venv`, con `uv pip` / `pip` |

Esta división es a propósito: Nix fija el **entorno**, no el ecosistema de
PyPI. Así puedes cambiar de versión de una librería sin tocar el flake, y
cambiar de Python sin tocar tus dependencias.

## Dependencias del proyecto

```bash
uv pip install -r requirements.txt     # desde un requirements.txt
uv pip install fastapi uvicorn         # sueltas
uv init && uv add rich                 # proyecto nuevo con pyproject.toml
```

`pip` también funciona dentro del `.venv` (viene de `ensurepip`), para cuando
el músculo tira de memoria. `uv` es lo rápido:

```bash
uv sync          # con pyproject.toml + uv.lock
uv run pytest    # ejecuta en el entorno del proyecto sin activar nada
```

## Cambiar de versión de Python

Edita `pythonVersion` en la cabecera de `flake.nix` (`"3.11"` a `"3.15"` en
nixpkgs 26.05), sal del shell y **recrea el venv**:

```bash
rm -rf .venv
nix develop
```

El `shellHook` avisa si el `.venv` que encuentra se creó con otra versión: un
venv viejo apunta al intérprete del store que lo creó y *shadowea* al del flake
sin decir nada. Las wheels nativas (numpy, pydantic-core, cryptography…) no
valen de una versión menor a otra. También avisa si el venv ya no arranca porque
su intérprete desapareció del store (típico después de un `nix-collect-garbage`).

`UV_PYTHON_DOWNLOADS=never` está puesto a propósito: `uv` no se bajará un
CPython por su cuenta. Si un `requires-python` no encaja con el del flake, uv
falla con un mensaje claro en vez de traerse otro intérprete a escondidas.

## Configuración

Todo en la cabecera de `flake.nix`:

| Opción | Para qué |
|---|---|
| `pythonVersion` | versión del intérprete (`"3.14"` por defecto) |
| `autoVenv` | crear y activar `.venv` al entrar (`true` por defecto). Ponlo en `false` si usas Poetry o PDM y gestionas tú el entorno |
| `extraPackages` | libs del **sistema** que necesitan las wheels o los sdist: `libpq`, `openssl`, `cmake`, `pkg-config`… |

`extraPackages` no son paquetes de pip: entran en el PATH y en
`LD_LIBRARY_PATH`, que es lo que necesitan las wheels que hacen `dlopen`
(psycopg, cairo, pygame) y los paquetes que compilan C al instalarse.

## Pureza: `nix develop` no es hermético

`nix develop` **antepone** el PATH de Nix, pero conserva el tuyo. Esto se cuela:

- **pyenv, conda, asdf**: dejan su `python` en el PATH. El `shellHook` avisa si
  el `python3` que se usaría no está en `/nix/store`.
- **`pip install --user`**: los paquetes de `~/.local/lib/python3.X/site-packages`
  aparecen en tu venv sin estar en `requirements.txt`. Por eso el shell exporta
  `PYTHONNOUSERSITE=1`.
- **`python` de Windows** en WSL: si el proyecto está en `/mnt/c`, no lo llames
  desde Windows con el mismo `.venv`, ni al revés. Un venv pertenece a un
  intérprete concreto; el de Windows no ejecuta el Python de Nix.

Para un shell realmente aislado (reproducir un fallo de CI):

```bash
nix develop -i -k HOME -k TERM
```

## WSL y carpetas de Windows

Funciona, con dos avisos:

- Un proyecto en `/mnt/c` va lento (cada `stat` cruza a NTFS). El repo en el
  home de Linux (`~/proyectos/...`) va mucho mejor; el código se sigue editando
  desde Windows con VS Code vía `\\wsl$`.
- `UV_LINK_MODE=copy` ya está puesto en el `flake.nix`: el cache de uv y el
  proyecto pueden estar en sistemas de archivos distintos, y ahí los hardlinks
  fallan. Si tu proyecto vive en ext4 y quieres la instalación más rápida,
  quita esa variable.

## Recuerda

`git add flake.nix flake.lock` — un flake **ignora los archivos que git no
rastrea**, y el `flake.lock` es lo que fija la revisión exacta de nixpkgs.

## Qué comprueba `nix flake check`

| Check | Qué rompe si falla |
|---|---|
| `version` | el atributo `pythonNNN` de nixpkgs ya no es la versión pedida |
| `venv` | `python -m venv` deja de traer pip (`ensurepip` roto) |
| `uv-offline` | uv intenta descargarse un CPython: el sandbox no tiene red, así que falla |

Los tres se construyen en CI. El tercero es el que más vale: es la garantía de
que entrar al shell no depende de la red.
