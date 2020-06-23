{
  description = "(insert short project description here)";

  # Nixpkgs / NixOS version to use.  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";

  # Upstream source tree(s).
  inputs.wireguard-rs = { url = git+https://git.zx2c4.com/wireguard-rs; flake = false; };

  outputs = { self, nixpkgs, wireguard-rs  }:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 wireguard-rs.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        wireguard-rs = with final; rustPlatform.buildRustPackage rec {
          name = "wireguard-rs-${version}";

          src = wireguard-rs;

          cargoSha256 = "078dd2sx3mayrrh2spzk9giy5x35h1gyi0y4c7bjpqlx0rfxcnnd";
          verifyCargoDeps = true; # the wireguard-rs repo doesn't have a Cargo.lock file

          meta = {
            homepage = "https://wireguard-rs.yoshuawuyts.com/";
            description = "Rust implimentation of dat.foundation";
          };
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) wireguard-rs;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.wireguard-rs);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.wireguard-rs =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.wireguard-rs ]; # FIX do we need these in environment.Systempakages? Implied by nixpkgs manual

          #systemd.services = { ... };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) wireguard-rs;

        # Additional tests, if applicable.
        test =
          with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "wireguard-rs-test-${version}";

            buildInputs = [ wireguard-rs ];

            unpackPhase = "true";

            buildPhase = ''
              echo 'running some integration tests'
              ./bin/wireguard-rs
            ''; # this should return with "Error: no device name suppoed"

            installPhase = "mkdir -p $out";
          };

        # A VM test of the NixOS module.
        vmTest =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") {
            inherit system;
          };

          makeTest {
            nodes = {
              client = { ... }: {
                imports = [ self.nixosModules.wireguard-rs ];
              };
            };

            testScript =
              ''
                main()
                async()
                iter()
                client.wait_for_unit("multi-user.target")
                client.succeed("wireguard-rs")
              '';
          };
      });

    };
}
