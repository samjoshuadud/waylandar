import sys

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'toggle-account':
        from core.cli import handle_toggle_account_cli
        handle_toggle_account_cli(sys.argv)
    elif '--background' in sys.argv:
        from core.daemon import background_sync
        background_sync()
    else:
        from core.cli import interactive_wizard
        interactive_wizard()
