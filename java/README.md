# Proyecto Java con Nix

```bash
nix develop          # entrar al entorno
nix develop -c ./gradlew test   # comando suelto, sin entrar
```

Configuración: cabecera de `flake.nix` (`jdkVersion`, `useNixGradle`).

**Importante:** commitea `flake.lock`. Es lo que fija la versión exacta
de todo. Y recuerda `git add` de los archivos nuevos: un flake sólo ve
lo que git rastrea.

## Pureza: `nix develop` no es hermético

`nix develop` **antepone** el PATH de Nix, pero conserva el tuyo. Si tienes
SDKMAN, su `gradle` o su `java` siguen alcanzables por detrás:

```bash
nix develop -c bash -c 'command -v gradle'
# -> ~/.sdkman/candidates/gradle/current/bin/gradle   ← fuga
```

Para un shell realmente aislado (útil para reproducir un fallo de CI):

```bash
nix develop -i -k HOME -k TERM
# PATH queda 100% /nix/store; lo del sistema desaparece
```

`-i` = ignorar el entorno, `-k VAR` = conservar esa variable.
