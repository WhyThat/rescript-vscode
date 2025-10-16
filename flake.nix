{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
  }:
    utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {inherit system;};
      version_extension = "1.66.0";

      rescript-analysis = pkgs.ocamlPackages.buildDunePackage {
        pname = "analysis";
        version = version_extension;
        src = ./.;
        minimalOCamlVersion = "5.2.1";
        nativeBuildInputs = with pkgs; [ocamlPackages.cppo];
      };

      platformDir =
        if pkgs.stdenv.isLinux
        then "linux"
        else "darwin";

      rescript-language-server = pkgs.buildNpmPackage {
        pname = "rescript-language-server";
        version = version_extension;

        src = ./server;
        nativeBuildInputs = [pkgs.esbuild];
        npmDepsHash = "sha256-87jUMXtgr2IsX2H6ghXfEq7QeXMwgreAnmajmop34nU=";

        buildPhase = ''
          npm install
          mkdir analysis_binaries/${platformDir}
          cp ${rescript-analysis}/bin/rescript-editor-analysis analysis_binaries/${platformDir}/rescript-editor-analysis.exe
          esbuild src/cli.ts --bundle --sourcemap --outfile=out/cli.js --format=cjs --platform=node --loader:.node=file --minify
        '';
      };
    in {
      packages.default = rescript-language-server;
    });
}
