#!/usr/bin/env python3
import os
import shutil
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/"
ROOT = ROOT.rstrip("/")
if ROOT == "":
    ROOT = "/"

def p(path):
    return os.path.join(ROOT, path.lstrip("/")) if ROOT != "/" else path

def backup(path):
    bak = path + ".bak-suspend-20261020"
    if not os.path.exists(bak) and os.path.exists(path):
        shutil.copy2(path, bak)

def replace_once(path, old, new, label):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if new in text:
        print(f"SKIP {label}: already patched")
        return
    if old not in text:
        print(f"WARN {label}: pattern not found")
        return
    backup(path)
    text = text.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"PATCH {label}")

# 1. GPU governor path for RK3562
gov = p("/usr/local/bin/sleep_governors.sh")
if os.path.exists(gov):
    replace_once(gov, 'gpu="fde60000"', 'gpu="ff320000"', "sleep_governors GPU path")
else:
    print("WARN sleep_governors.sh missing")

# 2. Sleep hook: never restore a zero/missing brightness
hook = p("/usr/lib/systemd/system-sleep/sleep")
if os.path.exists(hook):
    old = '''    # Restore brightness
    echo $(cat /var/local/cur_bright.state) | sudo tee /sys/class/backlight/backlight/brightness'''
    new = '''    # Restore brightness; if the saved state is 0/missing (ES screensaver
    # blanked the panel before suspend), fall back to a visible level.
    br=$(cat /var/local/cur_bright.state 2>/dev/null || echo 0)
    case "$br" in ''|*[!0-9]*) br=60 ;; esac
    [ "$br" -lt 5 ] && br=60
    echo "$br" | sudo tee /sys/class/backlight/backlight/brightness'''
    replace_once(hook, old, new, "sleep hook brightness")
else:
    print("WARN sleep hook missing")

# 3. ES screensaver: avoid the buggy black backlight-off path
settings = p("/home/ark/.emulationstation/es_settings.cfg")
if os.path.exists(settings):
    replace_once(settings,
                 'name="ScreenSaverBehavior" value="black"',
                 'name="ScreenSaverBehavior" value="dim"',
                 "ES ScreenSaverBehavior black -> dim")
else:
    print("WARN es_settings.cfg missing")
