# Proyecto Java con Nix

```bash
nix develop          # entrar al entorno
nix develop -c ./gradlew test   # comando suelto, sin entrar
```

Configuración: cabecera de `flake.nix` (`jdkVersion`, `useNixGradle`).

**Importante:** commitea `flake.lock`. Es lo que fija la versión exacta
de todo. Y recuerda `git add` de los archivos nuevos: un flake sólo ve
lo que git rastrea.
