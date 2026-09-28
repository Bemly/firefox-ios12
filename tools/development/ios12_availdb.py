#!/usr/bin/env python3
"""Post-iOS-12 API table from an iPhoneOS SDK, and a scanner for patch diffs.

Build:  ios12_availdb.py <iPhoneOS.sdk> <out.json>
Scan:   git diff <base> HEAD -U0 -- patches | ios12_availdb.py --scan <db.json>

The table maps ObjC selector heads ("foo:"), classes, properties, C functions,
constants and enum cases to the iOS version that introduced them (only > 12.0),
from API_AVAILABLE / CT_AVAILABLE / NS_AVAILABLE_IOS / ... annotations.
It is heuristic: the scan lists candidates, a human checks each one for an
@available / __builtin_available / respondsToSelector guard. Used because mach
folds compiler warnings in some directories (e.g. objc_video_capture), so a
clean Gecko log does not prove the engine is free of unguarded iOS 13+ calls.
"""
import glob, json, os, re, sys

FRAMEWORKS = ['AVFoundation', 'CoreVideo', 'CoreMedia', 'UIKit', 'CoreGraphics', 'Foundation',
              'IOSurface', 'VideoToolbox', 'CoreText', 'QuartzCore', 'CoreFoundation',
              'AudioToolbox', 'Metal', 'ImageIO', 'CoreImage', 'Security', 'CFNetwork',
              'SystemConfiguration', 'CoreTelephony', 'Network', 'MediaPlayer', 'Photos',
              'PhotosUI', 'LocalAuthentication', 'UserNotifications', 'WebKit']
AV = re.compile(r'\b(\w*(?:AVAILABLE|DEPRECATED)\w*|API_UNAVAILABLE)\s*\(([^;{}]*?)\)\s*(?=[;{]|$|\s)', re.S)


def ios_ver(args):
    m = re.search(r'ios\((\d+)[._]?(\d+)?', args)
    if m:
        return float(m.group(1) + '.' + (m.group(2) or '0'))
    m = re.match(r'\s*(\d+)[._](\d+)\s*$', args)  # NS_AVAILABLE_IOS(13_0)
    if m:
        return float(m.group(1) + '.' + m.group(2))
    m = re.search(r',\s*__IPHONE_(\d+)_(\d+)', args)
    if m:
        return float(m.group(1) + '.' + m.group(2))
    return None


def build(sdk, out):
    files = []
    for f in FRAMEWORKS:
        files += glob.glob(f'{sdk}/System/Library/Frameworks/{f}.framework/Headers/**/*.h', recursive=True)
    files += glob.glob(f'{sdk}/usr/include/os/*.h') + glob.glob(f'{sdk}/usr/include/objc/*.h')
    db = {}

    def add(name, ver, f):
        if not name or len(name) < 3:
            return
        cur = db.get(name)
        if cur is None or ver < cur[0]:
            db[name] = (ver, os.path.relpath(f, sdk))

    for f in files:
        txt = open(f, errors='ignore').read()
        txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
        txt = re.sub(r'//[^\n]*', '', txt)
        txt = re.sub(r'^[ \t]*#[^\n]*(\\\n[^\n]*)*', '', txt, flags=re.M)  # preprocessor lines
        for decl in re.split(r';|\{|\}', txt):
            for m in AV.finditer(decl):
                if m.group(1).startswith('API_UNAVAILABLE') or 'DEPRECATED' in m.group(1):
                    continue
                v = ios_ver(m.group(2))
                if v is None or v <= 12.0:
                    continue
                d = AV.sub(' ', decl[:m.start()] + ' ' + decl[m.end():])
                mm = re.search(r'@(?:interface|protocol)\s+(\w+)', d)
                if mm:
                    add(mm.group(1), v, f)
                    continue
                if re.search(r'^\s*[-+]\s*\(', d, re.M):  # ObjC method
                    parts = re.findall(r'(\w+)\s*:', d)
                    if parts:
                        add(parts[0] + ':', v, f)
                    else:
                        mm = re.search(r'\)\s*(\w+)\s*$', d.strip())
                        if mm:
                            add(mm.group(1), v, f)
                    continue
                mm = re.search(r'@property\s*(?:\([^)]*\))?[^;]*?\b(\w+)\s*$', d.strip(), re.S)
                if mm:
                    add(mm.group(1), v, f)
                    continue
                cands = [c for c in re.findall(r'\b([A-Za-z_]\w*)\s*\(', d)
                         if not re.match(r'^[A-Z_0-9]+$', c) and c not in ('__attribute__', 'sizeof', 'typeof', '__typeof__')]
                if cands:
                    add(cands[0], v, f)
                    continue
                mm = re.search(r'\b(\w+)\s*(?:=\s*[^,]*)?\s*,?\s*$', d.strip())
                if mm:
                    add(mm.group(1), v, f)
            for mm in re.finditer(r'\b([A-Z]\w+)\s+\w*AVAILABLE\w*\s*\(([^)]*\)[^)]*)\)', decl):  # enum cases
                v = ios_ver(mm.group(2))
                if v and v > 12.0:
                    add(mm.group(1), v, f)
    json.dump(db, open(out, 'w'))
    print(f'{len(db)} post-iOS-12 symbols -> {out}')


def scan(dbpath):
    db = json.load(open(dbpath))
    cur, seen = None, set()
    for line in sys.stdin:
        if line.startswith('+++ b/'):
            cur = line[6:].strip()
            continue
        # added lines of the patch file that are themselves added code ("++")
        if not line.startswith('++') or line.startswith('+++') or not cur:
            continue
        if not re.search(r'\.(mm|m|h|cpp|c)\.patch$', cur):
            continue
        code = re.sub(r'//.*', '', line[2:])
        # selector heads + identifiers that look like SDK API (skip lowercase
        # plain words: they collide with generic property names like "data")
        toks = {t + ':' for t in re.findall(r'\b([A-Za-z_]\w*)\s*:', code)}
        toks |= {t for t in re.findall(r'\b([A-Za-z_]\w+)\b', code) if re.match(r'^(k?[A-Z]{2}|UI|AV|CV|CM|CG|CT|NS|VT|MTL|CF)', t)}
        for t in toks:
            if t in db and (cur, t, code.strip()) not in seen:
                seen.add((cur, t, code.strip()))
                print(f'  iOS {db[t][0]:<5} {t:<40} {cur.replace("patches/", "")}\n           {code.strip()[:150]}')
    print(f'  {len(seen)} candidate(s)')


if __name__ == '__main__':
    if sys.argv[1] == '--scan':
        scan(sys.argv[2])
    else:
        build(sys.argv[1], sys.argv[2])
