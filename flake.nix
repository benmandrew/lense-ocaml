{
  description = "lense-ocaml: show how OCaml types are represented at runtime";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f nixpkgs.legacyPackages.${system});

      # compiler-libs changes every release; dune-project enforces the same pin.
      ocamlFor = pkgs: pkgs.ocaml-ng.ocamlPackages_5_5;
      version = "0.1.0";

      # What the dune build reads.
      source = nixpkgs.lib.fileset.toSource {
        root = ./.;
        fileset = nixpkgs.lib.fileset.unions [
          ./dune-project
          ./lense_ocaml.opam
          ./bin
          ./src
          ./test
          ./vendor
          ./web/dune
          ./web/jsoo
        ];
      };
    in
    {
      packages = forAllSystems (pkgs:
        let ocamlPackages = ocamlFor pkgs; in rec {
          # The command-line tool. The check runs the cram goldens, the Stage 0
          # checks and 20 fuzz rounds, which compile checkers with ocamlfind.
          default = ocamlPackages.buildDunePackage {
            pname = "lense_ocaml";
            inherit version;
            src = source;
            doCheck = true;
            nativeCheckInputs = [ ocamlPackages.findlib ];
            meta = {
              description = "Show how OCaml types are represented at runtime";
              mainProgram = "lense-ocaml";
              platforms = systems;
            };
          };

          # lense_core compiled to JavaScript by js_of_ocaml, with the stdlib
          # .cmi files embedded.
          web-js = pkgs.stdenv.mkDerivation {
            pname = "lense-ocaml-web-js";
            inherit version;
            src = source;
            nativeBuildInputs = [
              ocamlPackages.ocaml
              ocamlPackages.dune_3
              ocamlPackages.findlib
              ocamlPackages.js_of_ocaml-compiler
            ];
            buildInputs = [ ocamlPackages.js_of_ocaml ];
            buildPhase = ''
              runHook preBuild
              dune build --profile release web/jsoo/lense_web.bc.js
              runHook postBuild
            '';
            installPhase = ''
              install -Dm444 _build/default/web/jsoo/lense_web.bc.js $out/lense_web.js
            '';
            # Static files: nothing to patch or strip.
            dontFixup = true;
          };

          # The browser front end, ready to serve as static files.
          web = pkgs.buildNpmPackage {
            pname = "lense-ocaml-web";
            inherit version;
            src = ./web;
            npmDeps = pkgs.importNpmLock { npmRoot = ./web; };
            npmConfigHook = pkgs.importNpmLock.npmConfigHook;
            LENSE_JS = "${web-js}/lense_web.js";
            LENSE_EXAMPLES_DIR = ./test;
            installPhase = "cp -r dist $out";
            dontFixup = true;
          };
        });

      checks = forAllSystems (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      });

      devShells = forAllSystems (pkgs:
        let ocamlPackages = ocamlFor pkgs; in {
          default = pkgs.mkShell {
            inputsFrom = [
              self.packages.${pkgs.stdenv.hostPlatform.system}.default
              self.packages.${pkgs.stdenv.hostPlatform.system}.web-js
            ];
            packages = [ ocamlPackages.findlib ocamlPackages.ocaml-lsp pkgs.nodejs ];
          };
        });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
