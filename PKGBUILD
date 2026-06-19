pkgname=waylandar-git
pkgver=1.0.0
pkgrel=1
pkgdesc="A standalone Wayland Google Calendar widget built with Quickshell and Python"
arch=('any')
url="https://github.com/samjoshuadud/waylandar" 
license=('MIT') 
depends=(
    'quickshell-git'
    'python'
    'python-google-api-python-client'
    'python-google-auth-httplib2'
    'python-google-auth-oauthlib'
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

  # Create the global executable bash wrappers
  install -d "$pkgdir/usr/bin"
  
  cat > "$pkgdir/usr/bin/waylandar-auth" <<EOF
#!/bin/bash
exec python /usr/share/waylandar/backend/fetch_calendar.py "\$@"
EOF

  cat > "$pkgdir/usr/bin/waylandar-widget" <<EOF
#!/bin/bash
exec quickshell -p /usr/share/waylandar/frontend/widget.qml
EOF

  cat > "$pkgdir/usr/bin/waylandar-dashboard" <<EOF
#!/bin/bash
exec quickshell -p /usr/share/waylandar/frontend/dashboard.qml
EOF

  # Make all wrappers executable
  chmod +x "$pkgdir/usr/bin/waylandar-"{auth,widget,dashboard}
}
