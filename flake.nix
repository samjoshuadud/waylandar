{
  description = "A standalone Wayland Google Calendar widget built with AGS and Python";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          quickshell
          uv
          python311
        ];

        shellHook = ''
          echo "hypr-gcal development environment loaded!"
          echo "Run 'uv run backend/fetch_calendar.py' to test the backend."
          echo "Run 'quickshell -p frontend/widget.qml' for the desktop widget."
          echo "Run 'quickshell -p frontend/dashboard.qml' for the full dashboard overlay."
        '';
      };
    };
}
