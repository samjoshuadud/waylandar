import sys

if __name__ == '__main__':
    if '--background' in sys.argv:
        from core.daemon import background_sync
        background_sync()
    else:
        from core.cli import interactive_wizard
        interactive_wizard()
