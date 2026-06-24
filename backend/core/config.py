import os
import json
import uuid

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


def migrate_config(data):
    modified = False
    providers = data.setdefault("providers", {})
    
    # 1. Migrate legacy Google configuration
    if "google" in providers:
        google_prov = providers["google"]
        if isinstance(google_prov, dict) and "accounts" not in google_prov:
            was_configured = google_prov.get("configured")
            google_prov["accounts"] = []
            if was_configured:
                acc_id = str(uuid.uuid4())
                google_prov["accounts"].append({
                    "id": acc_id,
                    "email": "Google",
                    "name": "Google Account",
                    "enabled": True
                })
                # Rename the legacy token.json if it exists
                cache_dir = os.path.expanduser('~/.cache/waylandar')
                legacy_token = os.path.join(cache_dir, 'token.json')
                new_token = os.path.join(cache_dir, f'token_{acc_id}.json')
                if os.path.exists(legacy_token):
                    try:
                        os.rename(legacy_token, new_token)
                    except OSError:
                        pass
            if "configured" in google_prov:
                del google_prov["configured"]
            modified = True

    # 2. Migrate legacy Nextcloud configuration
    if "nextcloud" in providers:
        nc_prov = providers["nextcloud"]
        if isinstance(nc_prov, dict) and "accounts" not in nc_prov:
            url = nc_prov.get("url")
            username = nc_prov.get("username")
            password = nc_prov.get("password")
            nc_prov["accounts"] = []
            if url and username and password:
                acc_id = str(uuid.uuid4())
                nc_prov["accounts"].append({
                    "id": acc_id,
                    "name": f"Nextcloud - {username}",
                    "url": url,
                    "username": username,
                    "password": password,
                    "enabled": True
                })
            for key in ["url", "username", "password"]:
                if key in nc_prov:
                    del nc_prov[key]
            modified = True

    # 3. Migrate legacy iCloud configuration
    if "icloud" in providers:
        ic_prov = providers["icloud"]
        if isinstance(ic_prov, dict) and "accounts" not in ic_prov:
            url = ic_prov.get("url")
            username = ic_prov.get("username")
            password = ic_prov.get("password")
            ic_prov["accounts"] = []
            if url and username and password:
                acc_id = str(uuid.uuid4())
                ic_prov["accounts"].append({
                    "id": acc_id,
                    "name": f"iCloud - {username}",
                    "url": url,
                    "username": username,
                    "password": password,
                    "enabled": True
                })
            for key in ["url", "username", "password"]:
                if key in ic_prov:
                    del ic_prov[key]
            modified = True

    # 4. Cleanup legacy active_provider string if it exists
    if "active_provider" in data:
        del data["active_provider"]
        modified = True

    return modified

def load_config():
    config = None
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r') as f:
                config = json.load(f)
        except Exception:
            config = {"providers": {}}
    else:
        # Backwards compatibility check
        creds_path = os.path.expanduser('~/.config/waylandar/credentials.json')
        if os.path.exists(creds_path):
            config = {"providers": {"google": {"configured": True}}}
        else:
            config = {"providers": {}}

    # Self-healing migration
    if migrate_config(config):
        save_config(config)
        
    return config

def save_config(config):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    # 0600 permissions for security
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    with os.fdopen(os.open(CONFIG_PATH, flags, 0o600), 'w') as f:
        json.dump(config, f, indent=2)
