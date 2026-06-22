{
  description = "A standalone Wayland Calendar widget built with Quickshell and Python (Supports Google & Nextcloud)";

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
        caldav
        icalendar
        recurring-ical-events
        cryptography
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
          cat > $out/bin/waylandar <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pythonEnv}/bin/python $out/share/waylandar/backend/sync.py "\$@"
          EOF
          chmod +x $out/bin/waylandar

          # Move Theme out of frontend so it isn't symlinked as read-only later
          mv $out/share/waylandar/frontend/Theme.qml $out/share/waylandar/fallback_Theme.qml

          # Create a common initialization script
          cat > $out/bin/waylandar-init-theme <<EOF
          if [ -f ~/.config/waylandar/frontend/Theme.qml ]; then cp ~/.config/waylandar/frontend/Theme.qml ~/.config/waylandar/Theme.qml.bak; fi
          rm -rf ~/.config/waylandar/frontend
          mkdir -p ~/.config/waylandar/frontend/components
          
          # Symlink all read-only frontend files to the writable config directory individually to preserve structure
          ln -sfn $out/share/waylandar/frontend/*.qml ~/.config/waylandar/frontend/ 2>/dev/null || true
          ln -sfn $out/share/waylandar/frontend/components/*.qml ~/.config/waylandar/frontend/components/ 2>/dev/null || true
          
          # Restore the Matugen theme backup AFTER the symlinks are generated, so it safely overwrites the default symlink
          if [ -f ~/.config/waylandar/Theme.qml.bak ]; then mv ~/.config/waylandar/Theme.qml.bak ~/.config/waylandar/frontend/Theme.qml; fi
          
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
        waylandar = {
          type = "app";
          program = "${waylandarPkg}/bin/waylandar";
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
