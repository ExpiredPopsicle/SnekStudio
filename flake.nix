{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.self.submodules = true;

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachSystem [ 
      "x86_64-linux"
    ] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Matches semver compliant versioning in project.godot
        regex = ".+config\/version=\"([[:alnum:]]+\.[[:alnum:]]+\.[[:alnum:]]-{0,1}[[:alnum:]]*+{0,1}[[:alnum:]]*)\".+";
      in {
        formatter.${system} = pkgs.alejandra;
        packages.default = pkgs.callPackage ./nix/package.nix {version = builtins.head (builtins.match regex (builtins.readFile ./project.godot));};
        packages.mediapipe = pkgs.callPackage ./nix/mediapipe.nix {};
      }
    );
}
