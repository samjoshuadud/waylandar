{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  quickshell,
  bash,
}:

let
  pythonEnv = python3.withPackages (ps: [
    ps.google-api-python-client
    ps.google-auth-httplib2
    ps.google-auth-oauthlib
    ps.caldav
    ps.icalendar
    ps.recurring-ical-events
    ps.cryptography
  ]);
in

stdenv.mkDerivation (finalAttrs: {
  pname = "waylandar";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "samjoshuadud";
    repo = "waylandar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+/zu58E7wlo9QzQlnp5D7R5plOAvc6I6785kZB1Lw+g=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/waylandar

    cp -r frontend backend theme_template.qml $out/share/waylandar/

    # Move Theme.qml out of frontend so it is not symlinked as read-only
    mv $out/share/waylandar/frontend/Theme.qml $out/share/waylandar/fallback_Theme.qml

    # Remove qmldir from installed frontend
    rm -f $out/share/waylandar/frontend/qmldir

    # Python backend CLI entry point
    cat > $out/bin/waylandar <<SCRIPT
    #!${bash}/bin/bash
    exec ${pythonEnv}/bin/python $out/share/waylandar/backend/sync.py "\$@"
    SCRIPT
    chmod +x $out/bin/waylandar

    # Theme initialization helper (sourced at launch to set up writable config dir)
    cat > $out/bin/waylandar-init-theme <<SCRIPT
    #!${bash}/bin/bash
    if [ -f ~/.config/waylandar/frontend/Theme.qml ]; then
      cp ~/.config/waylandar/frontend/Theme.qml ~/.config/waylandar/Theme.qml.bak
    fi
    rm -rf ~/.config/waylandar/frontend
    mkdir -p ~/.config/waylandar/frontend/components

    ln -sfn $out/share/waylandar/frontend/*.qml ~/.config/waylandar/frontend/ 2>/dev/null || true
    ln -sfn $out/share/waylandar/frontend/components/*.qml ~/.config/waylandar/frontend/components/ 2>/dev/null || true

    if [ -f ~/.config/waylandar/Theme.qml.bak ]; then
      mv ~/.config/waylandar/Theme.qml.bak ~/.config/waylandar/frontend/Theme.qml
    fi

    cp $out/share/waylandar/theme_template.qml ~/.config/waylandar/theme_template.qml
    chmod 644 ~/.config/waylandar/theme_template.qml

    if [ ! -f ~/.config/waylandar/frontend/Theme.qml ]; then
      cp $out/share/waylandar/fallback_Theme.qml ~/.config/waylandar/frontend/Theme.qml
      chmod 644 ~/.config/waylandar/frontend/Theme.qml
    fi
    SCRIPT
    chmod +x $out/bin/waylandar-init-theme

    # Widget launcher (compact desktop agenda)
    cat > $out/bin/waylandar-widget <<SCRIPT
    #!${bash}/bin/bash
    source $out/bin/waylandar-init-theme
    exec ${quickshell}/bin/quickshell -p ~/.config/waylandar/frontend/widget.qml
    SCRIPT
    chmod +x $out/bin/waylandar-widget

    # Dashboard launcher (full-month calendar overlay)
    cat > $out/bin/waylandar-dashboard <<SCRIPT
    #!${bash}/bin/bash
    source $out/bin/waylandar-init-theme
    exec ${quickshell}/bin/quickshell -p ~/.config/waylandar/frontend/dashboard.qml
    SCRIPT
    chmod +x $out/bin/waylandar-dashboard

    runHook postInstall
  '';

  meta = {
    description = "Standalone Wayland calendar widget and dashboard built with Quickshell and Python";
    longDescription = ''
      Waylandar is a standalone Wayland calendar widget and dashboard that
      supports Google Calendar, Nextcloud (CalDAV), Apple iCloud, ICS feed
      subscriptions, and local .ics directories. It features background sync
      with desktop notifications and optional Matugen theming integration.
    '';
    homepage = "https://github.com/samjoshuadud/waylandar";
    changelog = "https://github.com/samjoshuadud/waylandar/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ samjoshuadud ];
    platforms = lib.platforms.linux;
    mainProgram = "waylandar-widget";
  };
})
