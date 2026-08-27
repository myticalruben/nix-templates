{
  description = "Entorno de desarrollo Java + Gradle, reproducible con Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      # ═══════════════════════════════════════════════════════════════════
      #  ⚙️  CONFIGURACION — lo unico que sueles tocar
      # ═══════════════════════════════════════════════════════════════════

      # Version del JDK. Debe coincidir con la toolchain de tu build.gradle.kts
      # Disponibles en nixpkgs 25.05: 8, 11, 17, 21, 23, 24
      jdkVersion = 21;

      # ¿Quieres tambien el Gradle de nixpkgs en el PATH?
      #   false -> usas ./gradlew (el wrapper fija version + checksum)
      #   true  -> usas `gradle` del store (offline, pero version de nixpkgs)
      useNixGradle = false;

      # ═══════════════════════════════════════════════════════════════════

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs:
        let
          jdk = pkgs."jdk${toString jdkVersion}";
          gradle = pkgs.gradle.override { java = jdk; };
        in
        {
          default = pkgs.mkShell {
            name = "java${toString jdkVersion}-dev";

            packages = [ jdk ]
              ++ nixpkgs.lib.optional useNixGradle gradle
              ++ (with pkgs; [
                jdt-language-server   # LSP de Java
                google-java-format    # formateador
                # maven
              ]);

            JAVA_HOME = "${jdk}";

            # OJO: las propiedades org.gradle.java.installations.* NO funcionan
            # desde GRADLE_OPTS (eso configura el launcher, no el daemon).
            # Tienen que ir en gradle.properties. El hook de abajo lo verifica.
            shellHook = ''
              echo ""
              echo "  ⬢ Java $(java -version 2>&1 | head -n1 | cut -d'"' -f2)  ·  JAVA_HOME=$JAVA_HOME"

              if ls settings.gradle* build.gradle* >/dev/null 2>&1; then
                if ! grep -qs 'installations.auto-detect=false' gradle.properties; then
                  echo ""
                  echo "  ⚠  Toolchain SIN sellar: Gradle puede usar un JDK del sistema"
                  echo "     (o descargarse uno). Anade a gradle.properties:"
                  echo ""
                  echo "       org.gradle.java.installations.auto-detect=false"
                  echo "       org.gradle.java.installations.auto-download=false"
                  echo "       org.gradle.java.installations.fromEnv=JAVA_HOME"
                fi
              fi
              echo ""
            '';
          };
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
