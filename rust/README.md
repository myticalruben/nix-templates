# Rust con Nix — cuatro entornos

```bash
nix develop              # general
nix develop .#osdev      # kernels / bare metal
nix develop .#embedded   # robótica, microcontroladores
nix develop .#graphics   # wgpu / Vulkan / Bevy
```

## Por qué cuatro shells y no uno

Un solo shell con todo pesaría varios GB y mezclaría toolchains
incompatibles: `osdev` necesita **nightly** (por `build-std`), el resto
funciona en **stable**. Nix hace barato tener entornos separados — cada
uno se descarga sólo cuando lo usas por primera vez.

Los cuatro comparten el mismo `flake.lock`, así que las versiones no
divergen entre dominios.

---

## `osdev` — sistemas operativos

Toolchain **nightly** con `rust-src` y `llvm-tools-preview`, y los targets
`x86_64-unknown-none`, `aarch64-unknown-none-softfloat` y
`riscv64gc-unknown-none-elf`.

```bash
cargo build -Z build-std=core,alloc,compiler_builtins \
            -Z build-std-features=compiler-builtins-mem \
            --target x86_64-unknown-none
```

`build-std` recompila `core` y `alloc` para un target sin sistema operativo;
por eso hace falta `rust-src` (el código fuente de la stdlib) y nightly.

Arrancar en QEMU con UEFI — la variable `$OVMF_FD` ya apunta al firmware:

```bash
qemu-system-x86_64 -bios $OVMF_FD -drive format=raw,file=target/…/boot.img -serial stdio
```

Depurar el kernel: `qemu … -s -S` y en otra terminal `gdb -ex 'target remote :1234'`.

Incluye `limine` y `grub2` como bootloaders, y `xorriso` + `mtools` +
`dosfstools` para construir ISOs y particiones EFI.

---

## `embedded` — robótica

Targets ARM Cortex-M (M0 a M33), RISC-V 32 y `aarch64-unknown-linux-gnu`
para SBCs (Raspberry Pi, Jetson).

```bash
cargo generate --git https://github.com/rust-embedded/cortex-m-quickstart
cargo embed --target thumbv7em-none-eabihf     # compila, flashea y abre RTT
probe-rs run --chip STM32F411RETx target/…/mi-firmware
```

`flip-link` reordena la memoria para que un desbordamiento de pila dé un
fallo limpio en vez de corromper datos silenciosamente.

### Lo que Nix NO puede hacer por ti

`probe-rs` necesita **reglas udev** en `/etc/udev/rules.d/` para hablar con
la sonda sin `sudo`. Eso vive fuera del store y requiere permisos de root:

```bash
sudo curl -o /etc/udev/rules.d/69-probe-rs.rules \
  https://probe.rs/files/69-probe-rs.rules
sudo udevadm control --reload
```

Es un límite real de Nix en distros no-NixOS: gestiona tu *entorno de
desarrollo*, no la configuración del sistema.

### ROS 2

No está incluido: ROS 2 en Nix requiere el overlay de la comunidad y pesa
mucho. Si lo necesitas, añade a `inputs`:

```nix
nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay";
```

---

## `graphics` — wgpu, Vulkan, Bevy

El problema real aquí no es compilar, es **enlazar en tiempo de ejecución**.
`winit` y `wgpu` cargan `libvulkan.so.1`, `libwayland-client.so` y
`libxkbcommon.so` con `dlopen()`, que **no mira el rpath del binario**. Por eso
el shell exporta `LD_LIBRARY_PATH`; sin eso tu binario compila y peta al arrancar.

Variables ya configuradas:

| Variable | Para qué |
|---|---|
| `LD_LIBRARY_PATH` | que `dlopen()` encuentre vulkan/wayland/X11/GL |
| `VK_LAYER_PATH` | capas de validación de Vulkan |
| `LIBGL_DRIVERS_PATH` | drivers GL del mesa de Nix (crocus, iris, radeonsi) |
| `VULKAN_SW_ICD` | ruta a lavapipe (**no** activo por defecto) |

### Cuando el hardware no llega (o quieres reproducibilidad exacta)

El loader de Nix encuentra solo los ICD del sistema en `/usr/share/vulkan/icd.d`,
así que el hardware suele funcionar sin tocar nada. (Mesa cubre más de lo que
parece: `intel_hasvk` da Vulkan 1.2 incluso en Ivy Bridge / Gen7, de 2012.)

Si tu GPU no llega, o quieres que el render salga **idéntico bit a bit** en
cualquier máquina — útil para tests de imagen en CI:

```bash
export VK_DRIVER_FILES=$VULKAN_SW_ICD   # lavapipe: rasterizador software
vulkaninfo --summary
```

Es lento, pero es Vulkan 1.4 de verdad y sale del store, así que no depende
de qué drivers tenga instalada la máquina.

Nota: verás errores del loader tipo `libvulkan_asahi.so: cannot open shared
object file`. Son ICDs del sistema para GPUs que no tienes (Apple, Android);
el loader los ignora y sigue. Para silenciarlos, apunta al driver concreto:

```bash
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/intel_hasvk_icd.json
```

### Si tienes NVIDIA propietario

Los drivers propietarios no están en el store y no encajan con el mesa de Nix.
La solución de la comunidad es [nixGL](https://github.com/nix-community/nixGL).

---

## Pureza

`nix develop` antepone su PATH pero conserva el tuyo. Si tienes `rustup`
instalado, su `cargo` sigue ahí detrás — el shellHook te avisa si te alcanza.
Para aislamiento total:

```bash
nix develop -i -k HOME -k TERM .#graphics
```
