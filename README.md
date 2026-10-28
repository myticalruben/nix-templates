# nix-templates

Templates de entornos de desarrollo reproducibles con Nix.

## Uso

```bash
# proyecto nuevo (crea la carpeta)
nix flake new -t github:myticalruben/nix-templates#java ./mi-proyecto

# sobre una carpeta existente (no sobreescribe archivos)
cd mi-proyecto
nix flake init -t github:myticalruben/nix-templates#java
```

Atajo con el registry, para no escribir la URL cada vez:

```bash
nix registry add rt github:myticalruben/nix-templates
nix flake init -t rt#java
```

Cada template copia también su `flake.lock`, así que el proyecto nace con las
versiones ya fijadas: no depende del día en que lo crees.

## Templates

| Nombre | Descripción |
|---|---|
| `java` | JDK configurable (8, 11, 17, 21, 25) + Gradle, con la toolchain sellada |
| `rust` | Rust con 4 devShells: general, `osdev`, `embedded` (robótica), `graphics` |
| `python` | Python 3.11–3.15 (configurable) + `uv` + `ruff`, con `.venv` automático |
| `frontend` | Node 24 + pnpm; devShells para Angular y React/Vite |

`nix flake init -t <repo>` sin sufijo usa `java`, que es el template `default`.

## Requisitos y límites

- nixpkgs fijado: `nixos-26.05` en los cuatro templates, con su `flake.lock`
  commiteado.
- Linux y macOS, x86_64 y aarch64. En Rust, los shells `osdev`, `embedded` y
  `graphics` solo existen en Linux.
- `x86_64-darwin` funciona con este pin, pero nixpkgs avisa de que 26.05 será
  la última release en soportarlo.
- En Python, Nix pone el intérprete y las herramientas; las dependencias del
  proyecto viven en `.venv` (por eso `.gitignore` lo excluye). `uv` va con
  `UV_PYTHON_DOWNLOADS=never`: no se baja ni un CPython por su cuenta.
- En una máquina sin GPU con Vulkan, el shell `graphics` puede usar el
  rasterizador software del store: `export VK_DRIVER_FILES=$VULKAN_SW_ICD`.
- `probe-rs` necesita reglas udev en `/etc` (fuera del alcance de Nix); el
  README del template `rust` explica cómo instalarlas.

## Añadir un template nuevo

1. Crea la carpeta con su `flake.nix` dentro (p. ej. `python/`).
2. Regístrala en `templates` del `flake.nix` raíz.
3. Genera su lock: `cd python && nix flake lock`.
4. **`git add`** — un flake solo ve archivos rastreados por git, y eso incluye
   el `flake.lock`.

## CI

`.github/workflows/check.yml` evalúa los cuatro sistemas de cada template,
construye sus `checks` nativos (en Rust, que el ICD de lavapipe exista) y
comprueba que `nix flake init` deja un proyecto con `flake.nix` y `flake.lock`.

## Licencia

MIT — ver [LICENSE](LICENSE).
