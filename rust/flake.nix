{
  description = "Rust: desarrollo general, sistemas operativos, robotica/embebido y graficos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # rust-overlay da toolchains oficiales de rust-lang (stable Y nightly),
    # con `extensions` (rust-src, llvm-tools...) y `targets` (bare-metal, ARM...).
    # El rustc de nixpkgs no permite elegir targets ni nightly comodamente.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      # `follows` evita bajar DOS nixpkgs distintos (uno nuestro y otro suyo).
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # OJO: aqui NO usamos `nixpkgs.legacyPackages` como en el template de Java.
      # legacyPackages viene pre-instanciado y no admite overlays; para inyectar
      # rust-overlay hay que importar nixpkgs a mano.
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        }));
    in
    {
      devShells = forAllSystems (pkgs:
        let
          inherit (pkgs) lib;

          # ═══════════════════════════════════════════════════════════════
          #  TOOLCHAINS
          # ═══════════════════════════════════════════════════════════════

          # Stable, para desarrollo normal y graficos.
          stable = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
          };

          # Nightly + bare-metal. El desarrollo de SO necesita nightly por
          # `build-std` (recompilar core/alloc para un target sin sistema
          # operativo debajo) y features como naked_functions o asm_const.
          osdevToolchain = pkgs.rust-bin.nightly.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" "llvm-tools-preview" ];
            targets = [
              "x86_64-unknown-none"              # kernel x86-64 freestanding
              "aarch64-unknown-none-softfloat"   # kernel ARM64 (Raspberry Pi)
              "riscv64gc-unknown-none-elf"       # kernel RISC-V
            ];
          };

          # Microcontroladores. Stable basta: el ecosistema embedded-hal,
          # RTIC y Embassy funcionan en stable desde hace tiempo.
          embeddedToolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" "llvm-tools-preview" ];
            targets = [
              "thumbv6m-none-eabi"          # Cortex-M0/M0+  (RP2040, nRF51)
              "thumbv7m-none-eabi"          # Cortex-M3      (STM32F1)
              "thumbv7em-none-eabihf"       # Cortex-M4F/M7  (STM32F4/F7, nRF52)
              "thumbv8m.main-none-eabihf"   # Cortex-M33     (nRF5340, RP2350)
              "riscv32imac-unknown-none-elf" # ESP32-C3, GD32V
              "aarch64-unknown-linux-gnu"   # SBC Linux: Raspberry Pi, Jetson
            ];
          };

          # Herramientas que quiero en TODOS los shells.
          comun = with pkgs; [
            pkg-config      # para que los crates -sys encuentren libs del sistema
            cargo-nextest   # runner de tests mas rapido que `cargo test`
            taplo           # LSP + formateador de TOML (Cargo.toml)
            bacon           # `cargo check` en watch, muy comodo
          ];

          # Aviso comun: rustup del sistema puede colarse por detras.
          avisoRustup = ''
            if [ -d "$HOME/.cargo/bin" ] && [ -x "$HOME/.cargo/bin/rustup" ]; then
              actual="$(command -v cargo)"
              case "$actual" in
                /nix/store/*) : ;;
                *) echo "  ⚠  cargo NO viene de Nix sino de $actual (rustup). PATH contaminado." ;;
              esac
            fi
          '';
        in
        {
          # ═══════════════════════════════════════════════════════════════
          #  default — Rust de toda la vida
          # ═══════════════════════════════════════════════════════════════
          default = pkgs.mkShell {
            name = "rust";
            packages = [ stable pkgs.mold pkgs.cargo-watch ] ++ comun;

            # rust-analyzer necesita saber donde esta el codigo de la stdlib
            # para darte "go to definition" dentro de core/std.
            RUST_SRC_PATH = "${stable}/lib/rustlib/src/rust/library";

            shellHook = ''
              echo ""
              echo "  🦀 Rust $(rustc --version | cut -d' ' -f2)  ·  shell: default"
              echo "     otros shells:  nix develop .#osdev | .#embedded | .#graphics"
              ${avisoRustup}
              echo ""
            '';
          };

          # ═══════════════════════════════════════════════════════════════
          #  osdev — kernels, bootloaders, bare metal
          # ═══════════════════════════════════════════════════════════════
          osdev = pkgs.mkShell {
            name = "rust-osdev";
            packages = [ osdevToolchain ] ++ comun ++ (with pkgs; [
              qemu                    # emulador donde arrancaras tu kernel
              OVMF                    # firmware UEFI para QEMU (arranque moderno)
              nasm                    # ensamblador, para el trampolin de arranque
              xorriso                 # crear ISOs booteables
              grub2                   # bootloader clasico (BIOS/UEFI)
              limine                  # bootloader moderno, muy usado en osdev nuevo
              dosfstools mtools       # construir particiones FAT para ESP (UEFI)
              cargo-binutils          # cargo objdump/nm/size sobre llvm-tools
              cargo-bootimage         # empaqueta el kernel en imagen arrancable
              gdb                     # depurar el kernel via gdbstub de QEMU
              lld                     # linker de LLVM; el de GNU falla en freestanding
            ]);

            RUST_SRC_PATH = "${osdevToolchain}/lib/rustlib/src/rust/library";

            # Ruta al firmware UEFI, para `qemu -bios $OVMF_FD`
            OVMF_FD = "${pkgs.OVMF.fd}/FV/OVMF.fd";

            shellHook = ''
              echo ""
              echo "  🦀 osdev  ·  $(rustc --version | cut -d' ' -f1-2)"
              echo "  ├─ targets: x86_64-unknown-none, aarch64-unknown-none-softfloat,"
              echo "  │           riscv64gc-unknown-none-elf"
              echo "  ├─ qemu $(qemu-system-x86_64 --version | head -n1 | cut -d' ' -f4)  ·  OVMF_FD=$OVMF_FD"
              echo "  └─ build-std:  cargo build -Z build-std=core,alloc --target x86_64-unknown-none"
              ${avisoRustup}
              echo ""
            '';
          };

          # ═══════════════════════════════════════════════════════════════
          #  embedded — robotica: microcontroladores y SBCs
          # ═══════════════════════════════════════════════════════════════
          embedded = pkgs.mkShell {
            name = "rust-embedded";
            packages = [ embeddedToolchain ] ++ comun ++ (with pkgs; [
              probe-rs-tools          # flashear y depurar por SWD/JTAG; trae cargo-embed
              cargo-binutils          # inspeccionar el binario (size, objdump)
              cargo-generate          # plantillas cortex-m-quickstart / embassy
              flip-link               # detecta desbordamiento de pila en MCU
              openocd                 # alternativa a probe-rs para JTAG
              picocom                 # consola serie
              pkgsCross.arm-embedded.buildPackages.gdb  # gdb que entiende ARM
              # ── Robotica de mas alto nivel ──
              # Los crates -sys de robotica suelen necesitar estas:
              udev                    # enumerar dispositivos USB/serie
              systemd                 # libudev para el crate `serialport`
              cmake clang             # muchos wrappers de C++ los piden
            ]);

            RUST_SRC_PATH = "${embeddedToolchain}/lib/rustlib/src/rust/library";

            shellHook = ''
              echo ""
              echo "  🦀 embedded  ·  $(rustc --version | cut -d' ' -f2)"
              echo "  ├─ targets: thumbv6m / thumbv7m / thumbv7em-hf / thumbv8m.main-hf,"
              echo "  │           riscv32imac, aarch64-linux (SBC)"
              echo "  └─ probe-rs $(probe-rs --version 2>/dev/null | head -n1 | cut -d' ' -f2)"
              echo ""
              echo "  ℹ  probe-rs necesita reglas udev para acceder a la sonda sin root."
              echo "     Nix NO puede instalarlas (van en /etc). Una vez, con sudo:"
              echo "     https://probe.rs/docs/getting-started/probe-setup/"
              ${avisoRustup}
              echo ""
            '';
          };

          # ═══════════════════════════════════════════════════════════════
          #  graphics — wgpu, Vulkan, winit, Bevy
          # ═══════════════════════════════════════════════════════════════
          graphics =
            let
              # Bibliotecas que winit/wgpu cargan en RUNTIME con dlopen().
              # No basta con enlazarlas: hay que ponerlas en LD_LIBRARY_PATH,
              # porque dlopen() no mira el rpath del ejecutable.
              runtimeLibs = with pkgs; [
                vulkan-loader
                mesa            # drivers GL (incl. crocus para Intel Gen7) + lavapipe
                libGL
                wayland
                libxkbcommon
                libdrm
                xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr
                fontconfig
                alsa-lib      # audio, si usas Bevy
                udev          # mandos / gamepads
              ];
            in
            pkgs.mkShell {
              name = "rust-graphics";
              packages = [ stable ] ++ comun ++ runtimeLibs ++ (with pkgs; [
                vulkan-tools              # vulkaninfo, vkcube
                vulkan-validation-layers  # capas de validacion (imprescindibles)
                vulkan-headers
                shaderc                   # glslc: GLSL -> SPIR-V
                glslang spirv-tools       # validar y desensamblar SPIR-V
                renderdoc                 # captura y analisis de frames
                mesa-demos                # glxgears, para comprobar OpenGL
              ]);

              RUST_SRC_PATH = "${stable}/lib/rustlib/src/rust/library";

              LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibs;

              # Capas de validacion de Vulkan (las busca el loader por esta ruta)
              VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

              # Drivers OpenGL del mesa de Nix, no los del sistema.
              # (crocus cubre Intel Gen7/Ivy Bridge, iris Gen8+, radeonsi AMD)
              LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";

              # Rasterizador software de Vulkan, tambien de Nix: funciona en
              # CUALQUIER maquina, incluso sin GPU con soporte Vulkan.
              # NO se activa solo; para forzarlo:  export VK_DRIVER_FILES=$VULKAN_SW_ICD
              VULKAN_SW_ICD = "${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.x86_64.json";

              shellHook = ''
                echo ""
                echo "  🦀 graphics  ·  Rust $(rustc --version | cut -d' ' -f2)"
                echo "  ├─ shaderc $(glslc --version 2>/dev/null | head -n1 | grep -o 'v[0-9.]*' | head -n1)  ·  renderdoc  ·  capas de validacion activas"
                echo "  └─ LD_LIBRARY_PATH configurado para winit/wgpu (dlopen)"
                echo ""
                # El loader de Vulkan busca ICDs del sistema por su cuenta
                # (/usr/share/vulkan/icd.d). Le decimos al usuario que ve.
                n=0
                [ -d /usr/share/vulkan/icd.d ] && n=$(ls -1 /usr/share/vulkan/icd.d/*.json 2>/dev/null | wc -l)
                echo "  ℹ  Vulkan: $n driver(s) del sistema detectados en /usr/share/vulkan/icd.d"
                echo "     Sin GPU compatible o para un resultado reproducible, fuerza software:"
                echo "       export VK_DRIVER_FILES=\$VULKAN_SW_ICD    # lavapipe, desde Nix"
                ${avisoRustup}
                echo ""
              '';
            };
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
