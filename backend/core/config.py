import os
import json

# ANSI Color Constants
C_HEADER = '\033[95m\033[1m'
C_BLUE = '\033[94m'
C_CYAN = '\033[96m'
C_GREEN = '\033[92m'
C_WARN = '\033[93m'
C_FAIL = '\033[91m'
C_END = '\033[0m'
C_BOLD = '\033[1m'

CONFIG_PATH = os.path.expanduser('~/.config/waylandar/config.json')

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
        except Exception:
            return {"active_provider": None, "providers": {}}
    else:
        # Backwards compatibility check
        creds_path = os.path.expanduser('~/.config/waylandar/credentials.json')
        if os.path.exists(creds_path):
            return {"active_provider": "google", "providers": {"google": {"configured": True}}}
        return {"active_provider": None, "providers": {}}

def save_config(config):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    # 0600 permissions for security
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    with os.fdopen(os.open(CONFIG_PATH, flags, 0o600), 'w') as f:
        json.dump(config, f, indent=2)
