{
  description = "Library for using Semantic Versioning in Emacs";

  nixConfig = {
    ## https://github.com/NixOS/rfcs/blob/master/rfcs/0045-deprecate-url-syntax.md
    extra-experimental-features = ["no-url-literals"];
    extra-substituters = ["https://cache.garnix.io"];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    ## Isolate the build.
    registries = false;
    ## This is false to allow _noChroot checks to run.
    sandbox = false;
  };

  outputs = inputs: let
    pname = "semver";
    ename = "emacs-${pname}";
  in
    {
      schemas = {
        inherit
          (inputs.project-manager.schemas)
          overlays
          homeConfigurations
          packages
          projectConfigurations
          devShells
          checks
          formatter
          ;
      };

      overlays = {
        default = final: prev: {
          emacsPackagesFor = emacs:
            (prev.emacsPackagesFor emacs).overrideScope'
            (inputs.self.overlays.emacs final prev);
        };

        emacs = final: prev: efinal: eprev: {
          "${pname}" = inputs.self.packages.${final.system}.${ename};
        };
      };

      homeConfigurations =
        builtins.listToAttrs
        (builtins.map
          (inputs.flaky.lib.homeConfigurations.example
            ename
            inputs.self
            [./nix/home-manager-example.nix])
          inputs.flake-utils.lib.defaultSystems);
    }
    // inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.flaky.overlays.elisp-dependencies];
      };

      src = pkgs.lib.cleanSource ./.;
    in {
      packages = {
        default = inputs.self.packages.${system}.${ename};
        "${ename}" = inputs.flaky.lib.elisp.package pkgs src pname (_: []);
      };

      projectConfigurations = inputs.flaky.lib.projectConfigurations.default {
        inherit pkgs;
        inherit (inputs) self;
      };

      devShells =
        inputs.self.projectConfigurations.${system}.devShells
        // {
          default =
            inputs.bash-strict-mode.lib.checkedDrv pkgs
            (pkgs.mkShell {
              inputsFrom =
                builtins.attrValues inputs.self.checks.${system}
                ++ builtins.attrValues inputs.self.packages.${system};

              nativeBuildInputs = [
                # Nix language server,
                # https://github.com/oxalica/nil#readme
                pkgs.nil
                # Bash language server,
                # https://github.com/bash-lsp/bash-language-server#readme
                pkgs.nodePackages.bash-language-server
              ];
            });
        };

      checks =
        inputs.self.projectConfigurations.${system}.checks
        // {
          elisp-doctor = inputs.flaky.lib.elisp.checks.doctor pkgs src;
          elisp-lint = inputs.flaky.lib.elisp.checks.lint pkgs src (_: []);
        };

      formatter = inputs.self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    bash-strict-mode = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:sellout/bash-strict-mode";
    };

    flake-utils.url = "github:numtide/flake-utils";

    flaky = {
      inputs = {
        bash-strict-mode.follows = "bash-strict-mode";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        project-manager.follows = "project-manager";
      };
      url = "github:sellout/flaky";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

    project-manager = {
      inputs = {
        bash-strict-mode.follows = "bash-strict-mode";
        flaky.follows = "flaky";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:sellout/project-manager";
    };
  };
}
