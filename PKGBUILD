pkgname=waylandar-git
pkgver=1.0.0
pkgrel=3
pkgdesc="A standalone Wayland Calendar widget built with Quickshell and Python (Supports Google & Nextcloud)"
arch=('any')
url="https://github.com/samjoshuadud/waylandar" 
license=('MIT') 
depends=(
    'quickshell-git'
    'python'
    'python-google-api-python-client'
    'python-google-auth-httplib2'
    'python-google-auth-oauthlib'
    'python-caldav'
    'python-icalendar'
    'python-recurring-ical-events'
    'python-cryptography'
)
makedepends=('git')
provides=('waylandar')
conflicts=('waylandar')
source=("git+https://github.com/samjoshuadud/waylandar.git") 
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/waylandar"
  printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  cd "$srcdir/waylandar"

  # Install the raw QML and Python source files into the shared system directory
  install -d "$pkgdir/usr/share/waylandar"
  cp -r frontend backend theme_template.qml "$pkgdir/usr/share/waylandar/"

  # Remove local Theme to force dynamic loading
  mv "$pkgdir/usr/share/waylandar/frontend/Theme.qml" "$pkgdir/usr/share/waylandar/fallback_Theme.qml"
  rm -f "$pkgdir/usr/share/waylandar/frontend/qmldir"

  # Create the global executable bash wrappers
  install -d "$pkgdir/usr/bin"
  
  cat > "$pkgdir/usr/bin/waylandar" <<EOF
#!/bin/bash
exec /usr/bin/python3 /usr/share/waylandar/backend/sync.py "\$@"
EOF

  cat > "$pkgdir/usr/bin/waylandar-widget" <<EOF
#!/bin/bash
if [ -f ~/.config/waylandar/frontend/Theme.qml ]; then cp ~/.config/waylandar/frontend/Theme.qml ~/.config/waylandar/Theme.qml.bak; fi
rm -rf ~/.config/waylandar/frontend
mkdir -p ~/.config/waylandar/frontend/components
if [ -f ~/.config/waylandar/Theme.qml.bak ]; then mv ~/.config/waylandar/Theme.qml.bak ~/.config/waylandar/frontend/Theme.qml; fi

ln -sfn /usr/share/waylandar/frontend/*.qml ~/.config/waylandar/frontend/ 2>/dev/null || true
ln -sfn /usr/share/waylandar/frontend/components/*.qml ~/.config/waylandar/frontend/components/ 2>/dev/null || true
cp /usr/share/waylandar/theme_template.qml ~/.config/waylandar/theme_template.qml
chmod 644 ~/.config/waylandar/theme_template.qml
if [ ! -f ~/.config/waylandar/frontend/Theme.qml ]; then
  cp /usr/share/waylandar/fallback_Theme.qml ~/.config/waylandar/frontend/Theme.qml
  chmod 644 ~/.config/waylandar/frontend/Theme.qml
fi
exec quickshell -p ~/.config/waylandar/frontend/widget.qml
EOF

  cat > "$pkgdir/usr/bin/waylandar-dashboard" <<EOF
#!/bin/bash
if [ -f ~/.config/waylandar/frontend/Theme.qml ]; then cp ~/.config/waylandar/frontend/Theme.qml ~/.config/waylandar/Theme.qml.bak; fi
rm -rf ~/.config/waylandar/frontend
mkdir -p ~/.config/waylandar/frontend/components
if [ -f ~/.config/waylandar/Theme.qml.bak ]; then mv ~/.config/waylandar/Theme.qml.bak ~/.config/waylandar/frontend/Theme.qml; fi

ln -sfn /usr/share/waylandar/frontend/*.qml ~/.config/waylandar/frontend/ 2>/dev/null || true
ln -sfn /usr/share/waylandar/frontend/components/*.qml ~/.config/waylandar/frontend/components/ 2>/dev/null || true
cp /usr/share/waylandar/theme_template.qml ~/.config/waylandar/theme_template.qml
chmod 644 ~/.config/waylandar/theme_template.qml
if [ ! -f ~/.config/waylandar/frontend/Theme.qml ]; then
  cp /usr/share/waylandar/fallback_Theme.qml ~/.config/waylandar/frontend/Theme.qml
  chmod 644 ~/.config/waylandar/frontend/Theme.qml
fi
exec quickshell -p ~/.config/waylandar/frontend/dashboard.qml
EOF

  # Make all wrappers executable
  chmod +x "$pkgdir/usr/bin/waylandar" "$pkgdir/usr/bin/waylandar-widget" "$pkgdir/usr/bin/waylandar-dashboard"
}
