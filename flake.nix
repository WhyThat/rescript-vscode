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
      version_extension = "1.72.0";

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

      # Build server dependencies separately
      server-deps = pkgs.buildNpmPackage {
        pname = "rescript-language-server-deps";
        version = version_extension;

        src = ./server;
        npmDepsHash = "sha256-ossX/zc9/gQgHmdB6sQzG/w1zYFbskAFCkzCberbNf8=";
        
        dontNpmBuild = true;

        installPhase = ''
          mkdir -p $out
          cp -r node_modules $out/
        '';
      };

      rescript-language-server = pkgs.buildNpmPackage {
        pname = "rescript-language-server";
        version = version_extension;

        src = ./.;
        nativeBuildInputs = [pkgs.esbuild];
        npmDepsHash = "sha256-aAKBTGm1NhYeJneBXo/m53gnjbmwE4OWC7VONfecnG8=";

        # Skip all npm lifecycle scripts
        npmFlags = ["--ignore-scripts"];

        buildPhase = ''
          # Link server dependencies
          ln -s ${server-deps}/node_modules server/node_modules
          
          # Create analysis binaries directory and copy the binary
          mkdir -p analysis_binaries/${platformDir}
          cp ${rescript-analysis}/bin/rescript-editor-analysis analysis_binaries/${platformDir}/rescript-editor-analysis.exe

          # Build the language server
          esbuild server/src/cli.ts --bundle --sourcemap --outfile=server/out/cli.js --format=cjs --platform=node --loader:.node=file --minify
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/lib
          
          # Copy server output and package.json
          cp -r server/out $out/lib/
          cp server/package.json $out/lib/
          cp -r analysis_binaries $out/lib/
          
          # Create executable wrapper
          cat > $out/bin/rescript-language-server <<EOF
          #!/bin/sh
          exec ${pkgs.nodejs}/bin/node $out/lib/out/cli.js "\$@"
          EOF
          chmod +x $out/bin/rescript-language-server

          runHook postInstall
        '';
      };
    in {
      packages.default = rescript-language-server;
    });
}
