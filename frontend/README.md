# Frontend development (Angular / React)

Plantilla de **entorno de desarrollo**, no generador automático de aplicaciones.
Mantiene Node.js, npm y pnpm disponibles mediante Nix; las dependencias de
Angular/React se gestionan **por proyecto** con `package.json` y su lockfile.

## Crear el entorno desde el repositorio de templates

```sh
nix flake new -t github:myticalruben/nix-templates#frontend ./mi-frontend
cd mi-frontend
```

## Angular

```sh
nix develop .#angular
npx @angular/cli@latest new mi-app
cd mi-app
npm start
```

Si `mi-app` ya existe, entra a su directorio y ejecuta `npm ci` (si existe
`package-lock.json`) y luego `npm start`.

## React + TypeScript (Vite)

```sh
nix develop .#react
npm create vite@latest mi-app -- --template react-ts
cd mi-app
npm install
npm run dev
```

`nix develop` sin sufijo entra a la shell `default`, equivalente a `react`.

## Reproducibilidad

- `flake.lock` fija la revision de nixpkgs y las herramientas provistas por Nix.
- `package-lock.json` o `pnpm-lock.yaml` fija las dependencias JavaScript.
- Usa `npm ci` en proyectos con lockfile de npm existente.
- La CLI de Angular y Vite se instalan como dependencias del proyecto generado;
  no se fija su version desde este flake.
- Node.js 24 se selecciona para compatibilidad con Angular 22 y Vite reciente; para
  frameworks futuros se puede cambiar a una version soportada por nixpkgs.
- Si copias este archivo en un repositorio Git, registra `flake.nix` con `git add`.

Sistemas anunciados: Linux y macOS (x86_64/aarch64). No se incluyen
herramientas para compilar aplicaciones moviles ni un navegador embebido.
