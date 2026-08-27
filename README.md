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

## Templates

| Nombre | Descripción |
|---|---|
| `java` | JDK (versión configurable) + Gradle, con la toolchain de Gradle sellada |
| `rust` | Rust con 4 devShells: general, `osdev`, `embedded` (robótica), `graphics` |

## Añadir un template nuevo

1. Crea la carpeta con su `flake.nix` dentro (p. ej. `python/`).
2. Regístrala en `templates` del `flake.nix` raíz.
3. **`git add`** — un flake sólo ve archivos rastreados por git.
