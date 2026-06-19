{
  description = "A standalone Wayland Google Calendar widget built with AGS and Python";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      pythonEnv = pkgs.python3.withPackages (ps: with ps; [
        google-api-python-client
        google-auth-httplib2
        google-auth-oauthlib
      ]);

      waylandarPkg = pkgs.stdenv.mkDerivation {
        pname = "waylandar";
        version = "1.0.0";
        src = ./.;

        buildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/share/waylandar

          cp -r frontend backend theme_template.qml $out/share/waylandar/

          # Wrap the python auth script
          cat > $out/bin/waylandar-auth <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pythonEnv}/bin/python $out/share/waylandar/backend/fetch_calendar.py "\$@"
          EOF
          chmod +x $out/bin/waylandar-auth

          # Wrap the quickshell widget launcher
          cat > $out/bin/waylandar-widget <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pkgs.quickshell}/bin/quickshell -p $out/share/waylandar/frontend/widget.qml
          EOF
          chmod +x $out/bin/waylandar-widget

          # Wrap the quickshell dashboard launcher
          cat > $out/bin/waylandar-dashboard <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pkgs.quickshell}/bin/quickshell -p $out/share/waylandar/frontend/dashboard.qml
          EOF
          chmod +x $out/bin/waylandar-dashboard
        '';
      };
    in
    {
      packages.${system}.default = waylandarPkg;

      apps.${system} = {
        waylandar-widget = {
          type = "app";
          program = "${waylandarPkg}/bin/waylandar-widget";
        };
        waylandar-dashboard = {
          type = "app";
          program = "${waylandarPkg}/bin/waylandar-dashboard";
        };
        waylandar-auth = {
          type = "app";
          program = "${waylandarPkg}/bin/waylandar-auth";
        };
        default = {
          type = "app";
          program = "${waylandarPkg}/bin/waylandar-widget";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.quickshell
          pkgs.uv
          pythonEnv
        ];

        shellHook = ''
          echo "waylandar development environment loaded!"
        '';
      };
    };
}
