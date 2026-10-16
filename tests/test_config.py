import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Ensure backend modules can be imported
backend_dir = Path(__file__).resolve().parent.parent / "backend"
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from core import cli, config  # noqa: E402


class TestConfigMigrationAndValidation(unittest.TestCase):
    def test_migrate_config_adds_default_time_format_if_missing(self):
        data = {}
        modified = config.migrate_config(data)
        self.assertTrue(modified)
        self.assertEqual(data.get("time_format"), "12h")

    def test_migrate_config_preserves_valid_12h(self):
        data = {"time_format": "12h", "display_mode": "all"}
        modified = config.migrate_config(data)
        self.assertFalse(modified)
        self.assertEqual(data["time_format"], "12h")

    def test_migrate_config_preserves_valid_24h(self):
        data = {"time_format": "24h", "display_mode": "all"}
        modified = config.migrate_config(data)
        self.assertFalse(modified)
        self.assertEqual(data["time_format"], "24h")

    def test_migrate_config_normalizes_shorthand_and_case(self):
        for val in ["24H", "24"]:
            data = {"time_format": val, "display_mode": "all"}
            modified = config.migrate_config(data)
            self.assertTrue(modified)
            self.assertEqual(data["time_format"], "24h")

    def test_migrate_config_resets_invalid_time_format(self):
        for invalid_val in ["unknown", "xyz", "", None, 12, "48h"]:
            data = {"time_format": invalid_val, "display_mode": "all"}
            modified = config.migrate_config(data)
            self.assertTrue(modified)
            self.assertEqual(data["time_format"], "12h")

    def test_load_config_with_empty_or_new_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            test_cfg_path = os.path.join(tmpdir, "config.json")
            with patch.object(config, "CONFIG_PATH", test_cfg_path):
                cfg = config.load_config()
                self.assertEqual(cfg.get("time_format"), "12h")
                self.assertTrue(os.path.exists(test_cfg_path))
                with open(test_cfg_path, "r") as f:
                    saved = json.load(f)
                self.assertEqual(saved.get("time_format"), "12h")

    def test_load_config_preserves_24h(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            test_cfg_path = os.path.join(tmpdir, "config.json")
            with open(test_cfg_path, "w") as f:
                json.dump({"time_format": "24h", "display_mode": "all"}, f)
            with patch.object(config, "CONFIG_PATH", test_cfg_path):
                cfg = config.load_config()
                self.assertEqual(cfg.get("time_format"), "24h")


class TestCliTimeFormat(unittest.TestCase):
    @patch("builtins.input", return_value="2")
    @patch("core.cli.save_config")
    def test_change_time_format_to_24h(self, mock_save, mock_input):
        cfg = {"time_format": "12h"}
        cli.change_time_format(cfg)
        self.assertEqual(cfg["time_format"], "24h")
        mock_save.assert_called_once_with(cfg)

    @patch("builtins.input", return_value="1")
    @patch("core.cli.save_config")
    def test_change_time_format_to_12h(self, mock_save, mock_input):
        cfg = {"time_format": "24h"}
        cli.change_time_format(cfg)
        self.assertEqual(cfg["time_format"], "12h")
        mock_save.assert_called_once_with(cfg)

    @patch("builtins.input", return_value="invalid")
    @patch("core.cli.save_config")
    def test_change_time_format_invalid_choice(self, mock_save, mock_input):
        cfg = {"time_format": "12h"}
        cli.change_time_format(cfg)
        self.assertEqual(cfg["time_format"], "12h")
        mock_save.assert_not_called()


if __name__ == "__main__":
    unittest.main()
