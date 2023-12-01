{
  description = "general-template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };
  outputs =
    inputs @ { self
    , nixpkgs
    , ...
    }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.pre-commit-hooks-nix.flakeModule
      ];

      # `nix flake show --impure` hack
      systems =
        if builtins.hasAttr "currentSystem" builtins
        then [ builtins.currentSystem ]
        else inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem =
        { config
        , self'
        , inputs'
        , pkgs
        , system
        , ...
        }: {
          pre-commit.settings = {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
            };
          };

          devShells.default = pkgs.mkShell {
            shellHook = config.pre-commit.installationScript;
            nativeBuildInputs = [
              pkgs.fd
              pkgs.llvmPackages.bintools
              pkgs.llvmPackages.libcxxClang
              pkgs.clang
              pkgs.lld
              pkgs.blink
              pkgs.gdb
              pkgs.valgrind
              pkgs.hyperfine
            ];
            buildInputs = [
              pkgs.pkgsStatic.musl
            ];
          };

          formatter = pkgs.nixpkgs-fmt;
        };
    };
}
