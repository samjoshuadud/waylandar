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

          # Move Theme out of frontend so it isn't symlinked as read-only later
          mv $out/share/waylandar/frontend/Theme.qml $out/share/waylandar/fallback_Theme.qml
          
          # Wrap the python auth script
          cat > $out/bin/waylandar-auth <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pythonEnv}/bin/python $out/share/waylandar/backend/fetch_calendar.py "\$@"
          EOF
          chmod +x $out/bin/waylandar-auth

          # Create a common initialization script
          cat > $out/bin/waylandar-init-theme <<EOF
          mkdir -p ~/.config/waylandar/frontend
          # Symlink all read-only frontend files to the writable config directory
          ln -sfn $out/share/waylandar/frontend/* ~/.config/waylandar/frontend/
          
          # Copy the template for Matugen to use
          cp $out/share/waylandar/theme_template.qml ~/.config/waylandar/theme_template.qml
          chmod 644 ~/.config/waylandar/theme_template.qml
          
          # Copy the fallback Theme.qml ONLY if Matugen hasn't generated one
          if [ ! -f ~/.config/waylandar/frontend/Theme.qml ]; then
            cp $out/share/waylandar/fallback_Theme.qml ~/.config/waylandar/frontend/Theme.qml
            chmod 644 ~/.config/waylandar/frontend/Theme.qml
          fi
          EOF
          chmod +x $out/bin/waylandar-init-theme

          # Wrap the quickshell widget launcher
          cat > $out/bin/waylandar-widget <<EOF
          #!${pkgs.bash}/bin/bash
          source $out/bin/waylandar-init-theme
          exec ${pkgs.quickshell}/bin/quickshell -p ~/.config/waylandar/frontend/widget.qml
          EOF
          chmod +x $out/bin/waylandar-widget

          # Wrap the quickshell dashboard launcher
          cat > $out/bin/waylandar-dashboard <<EOF
          #!${pkgs.bash}/bin/bash
          source $out/bin/waylandar-init-theme
          exec ${pkgs.quickshell}/bin/quickshell -p ~/.config/waylandar/frontend/dashboard.qml
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
