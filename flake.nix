{
  description = "Templates de entornos de desarrollo con Nix — Ruben";

  # Este flake NO necesita inputs: no construye nada, solo expone carpetas.
  # (nixpkgs lo declara cada template por su cuenta, en su propio flake.nix)
  outputs = { self }: {

    # ═══════════════════════════════════════════════════════════════════
    # templates = el output que consume `nix flake init -t`.
    # Cada entrada es:
    #   path        -> carpeta de ESTE repo que se copiara al proyecto nuevo
    #   description -> lo que muestra `nix flake show`
    #   welcomeText -> markdown que Nix imprime tras copiar (instrucciones)
    # ═══════════════════════════════════════════════════════════════════
    templates = {

      java = {
        path = ./java;
        description = "Java (JDK configurable) + Gradle — devShell con toolchain sellada";
        welcomeText = ''
          # Entorno Java listo ✅

          ## Siguientes pasos

          1. `nix develop`                  — entrar al entorno
          2. `gradle init`                  — si el proyecto aun esta vacio
          3. Sella la toolchain: anade a `gradle.properties`

             ```
             org.gradle.java.installations.auto-detect=false
             org.gradle.java.installations.auto-download=false
             org.gradle.java.installations.fromEnv=JAVA_HOME
             ```

             (el shellHook te avisa si falta)

          ## Cambiar de JDK

          Edita `jdkVersion` en la cabecera de `flake.nix` y vuelve a entrar.

          ## Recuerda

          `git add flake.nix flake.lock` — un flake **ignora los archivos
          que git no rastrea**.
        '';
      };

      # Alias: permite `nix flake init -t <repo>` sin sufijo #java
      default = self.templates.java;
    };
  };
}
