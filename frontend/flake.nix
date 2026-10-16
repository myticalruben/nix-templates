{
  description = "Frontend development — Angular and React development shells";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = function:
        nixpkgs.lib.genAttrs systems (system:
          function (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs:
        let
          commonPackages = with pkgs; [
            nodejs_24
            pnpm
            git
          ];

          makeFrontendShell = framework: pkgs.mkShell {
            name = "frontend-${framework}";
            packages = commonPackages;

            shellHook = ''
              echo ""
              echo "Frontend development shell: ${framework}"
              echo "Node: $(node --version) | npm: $(npm --version) | pnpm: $(pnpm --version)"
              echo ""
            '' + (if framework == "angular" then ''
              echo "Angular: npx @angular/cli@latest new my-app"
              echo "Existing project: npm ci && npm start"
            '' else ''
              echo "React: npm create vite@latest my-app -- --template react-ts"
              echo "Existing project: npm ci && npm run dev"
            '');
          };
        in
        {
          default = makeFrontendShell "react";
          angular = makeFrontendShell "angular";
          react = makeFrontendShell "react";
        });
    };
}
