"""Reproducible brand assets. Run sources, Flutter renderer, then package/check.

python tool/generate_brand_icons.py sources
flutter test --no-pub tool/render_brand_icons.dart
python tool/generate_brand_icons.py package
python tool/generate_brand_icons.py check
"""
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/images'
BUILD = ROOT / 'build/brand_icons'
RES = ROOT / 'android/app/src/main/res'
OUT = ROOT / 'design/brand_icons'
STYLES = ['official', 'classic', 'aqua', 'premium', 'speed', 'sky', 'sunset', 'blue_night']
NAMES = ['官方默认', '经典', '水色', '高级版', '极速', '天空', '日落', '蓝夜']
# Simplified status silhouette traced from reference #1; app icons use its pixels.
WINGS = [
    'M75 136 C84 111 80 86 107 66 C126 50 173 65 200 53 '
    'C190 88 170 99 143 99 C113 98 91 112 75 136 Z',
    'M61 204 C65 179 67 151 85 133 C102 115 144 122 176 112 '
    'C168 142 148 152 124 151 C105 150 103 164 96 177 C88 191 74 199 61 204 Z',
]
ORBIT = 'M52 165 C15 145 91 106 170 100 C229 94 230 119 188 145 C154 166 86 181 52 165'


def gradient(name, colors):
    stops = ''.join(f'<stop offset="{i/(len(colors)-1):.3f}" stop-color="{c}"/>' for i, c in enumerate(colors))
    return f'<linearGradient id="{name}" x1="0" y1="0" x2=".8" y2="1">{stops}</linearGradient>'


def mark(dark, mono=False, orbit=True):
    color = '#ffffff' if mono else 'url(#wing)'
    trail = '#ffffff' if mono else ('#43e3ff' if dark else '#007ec9')
    ring = f'<path d="{ORBIT}" fill="none" stroke="{trail}" stroke-width="2.8" opacity=".85"/>' if orbit else ''
    dots = f'<circle cx="50" cy="162" r="6" fill="{trail}"/><circle cx="210" cy="107" r="7" fill="{trail}"/>' if orbit else ''
    paths = ''.join(f'<path d="{d}" fill="{color}"/>' for d in WINGS)
    return ring + paths + dots


def svg(body, defs=''):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><defs>{defs}</defs>{body}</svg>\n'


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')


def status_paths(style, android=False):
    if android:
        fill = '#00000000' if style == 'outline' else '#FFFFFFFF'
        stroke = ' android:strokeColor="#FFFFFFFF" android:strokeWidth="12" android:strokeLineJoin="round"' if style == 'outline' else ''
        paths = ''.join(f'<path android:fillColor="{fill}"{stroke} android:pathData="{d}"/>' for d in WINGS)
        if style == 'flow':
            paths += f'<path android:fillColor="#00000000" android:strokeColor="#FFFFFFFF" android:strokeWidth="7" android:pathData="{ORBIT}"/>'
        return paths
    fill = 'none' if style == 'outline' else '#ffffff'
    stroke = ' stroke="#ffffff" stroke-width="12" stroke-linejoin="round"' if style == 'outline' else ''
    paths = ''.join(f'<path fill="{fill}"{stroke} d="{d}"/>' for d in WINGS)
    if style == 'flow':
        paths += f'<path d="{ORBIT}" fill="none" stroke="#ffffff" stroke-width="7"/>'
    return paths


def vector(size, style='plain'):
    paths = status_paths(style, android=True)
    scale = (.09 if style == 'flow' else .11) if size == 24 else .31
    translate = .48 if style == 'flow' and size == 24 else (-2.08 if size == 24 else 14.32)
    return f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="{size}dp" android:height="{size}dp" android:viewportWidth="{size}" android:viewportHeight="{size}">
  <group android:scaleX="{scale}" android:scaleY="{scale}" android:translateX="{translate}" android:translateY="{translate}">{paths}</group>
</vector>
'''


def icon_cell(pair, dark):
    side = pair.width // 2
    left = 0 if dark else side
    cell = pair.crop((left, 0, left + side, pair.height))
    # Clip stray exterior glow to a clean platform silhouette; retain RGB detail.
    mask = Image.new('L', (side*4, side*4))
    inset = round(side*.015*4)
    ImageDraw.Draw(mask).rounded_rectangle((inset, inset, side*4-inset-1, side*4-inset-1), radius=round(side*.23*4), fill=255)
    cell.putalpha(ImageChops.multiply(cell.getchannel('A'), mask.resize(cell.size, Image.Resampling.LANCZOS)))
    return cell


def sources():
    metadata = {}
    (ASSETS / 'brand').mkdir(exist_ok=True)
    for style in STYLES:
        master = OUT / f'source/{style}_pair.png'
        pair = Image.open(master).convert('RGBA')
        assert abs(pair.width / 2 - pair.height) < 2, f'{style}: expected 2:1 dark/light pair'
        cell = pair.width // 2
        metadata[style] = {'master': str(master.relative_to(ROOT)).replace('\\', '/'),
                           'native_cell': [cell, pair.height], 'sha256': hashlib.sha256(master.read_bytes()).hexdigest()}
        for dark in (False, True):
            variant = f'{style}_{"dark" if dark else "light"}'
            square = icon_cell(pair, dark)
            artwork = square.resize((1024,1024), Image.Resampling.LANCZOS)
            artwork.save(ASSETS / f'brand_{variant}.png')
            artwork.save(ASSETS / f'brand/brand_{variant}.webp', lossless=True, method=6, exact=True)
            layer = Image.new('RGBA', (432,432))
            layer.paste(square.resize((288,288), Image.Resampling.LANCZOS), (72,72))
            (RES / 'drawable-xxxhdpi').mkdir(parents=True, exist_ok=True)
            layer.save(RES / f'drawable-xxxhdpi/brand_{variant}_foreground.png')
            bg = Image.new('RGB', (432,432), square.getpixel((cell//2, int(pair.height*.88)))[:3])
            bg.save(RES / f'drawable-xxxhdpi/brand_{variant}_background.png')
            adaptive = f'''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/brand_{variant}_background"/>
    <foreground android:drawable="@drawable/brand_{variant}_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
'''
            write(RES / f'mipmap-anydpi-v26/brand_{variant}.xml', adaptive)
    for name, dark, mono in [('fluxora_mark', True, False), ('fluxora_mark_light', False, False), ('fluxora_mark_mono', True, True)]:
        defs = gradient('wing', ['#00e3ed', '#008bff', '#004bcb'] if dark else ['#0076c7', '#009bc8', '#0049a1'])
        write(ASSETS / f'{name}.svg', svg(mark(dark, mono), defs))
    write(BUILD / 'status.svg', svg(f'<g transform="translate(-22 -22) scale(1.16)">{mark(True, True, False)}</g>'))
    for name in ['ic_notification_dark', 'ic_notification_light', 'ic_tile']:
        write(RES / f'drawable/{name}.xml', vector(24))
    for style in ['flow', 'plain', 'outline']:
        write(RES / f'drawable/ic_notification_{style}.xml', vector(24, style))
        write(ASSETS / f'notification_{style}.svg', svg(status_paths(style)))
    for folder in ['values', 'values-night', 'values-v27', 'values-night-v27']:
        styles = RES / folder / 'styles.xml'
        text = styles.read_text(encoding='utf-8')
        icon = '@mipmap/brand_official_dark' if 'night' in folder else '@mipmap/brand_official_light'
        text = re.sub(r'(<item name="windowSplashScreenAnimatedIcon">).*?(</item>)', lambda match: match[1] + icon + match[2], text)
        write(styles, text)
    write(RES / 'drawable-night/ic_tile.xml', vector(24))
    write(RES / 'drawable/ic_launcher_monochrome.xml', vector(108))
    for old, variant in [('ic_launcher', 'official_dark'), ('ic_launcher_round', 'official_dark'), ('ic_launcher_light', 'official_light'), ('ic_launcher_round_light', 'official_light')]:
        write(RES / f'mipmap-anydpi-v26/{old}.xml', (RES / f'mipmap-anydpi-v26/brand_{variant}.xml').read_text())
    manifest_path = ROOT / 'android/app/src/main/AndroidManifest.xml'
    manifest = manifest_path.read_text(encoding='utf-8')
    start, end = '        <!-- BEGIN GENERATED BRAND ICON ALIASES -->', '        <!-- END GENERATED BRAND ICON ALIASES -->'
    aliases = []
    for style in STYLES[1:]:
        for mode in ['light', 'dark']:
            name = ''.join(word.title() for word in style.split('_')) + mode.title()
            aliases.append(f'''        <activity-alias android:name="io.fluxora.app.Icon{name}"
            android:enabled="false" android:exported="true"
            android:icon="@mipmap/brand_{style}_{mode}" android:roundIcon="@mipmap/brand_{style}_{mode}"
            android:label="@string/fluxora" android:targetActivity="io.fluxora.app.MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
            <intent-filter><action android:name="android.service.quicksettings.action.QS_TILE_PREFERENCES" /></intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="clash" android:host="install-config" />
                <data android:scheme="clashmeta" android:host="install-config" />
                <data android:scheme="fluxora" android:host="install-config" />
            </intent-filter>
        </activity-alias>''')
    generated = start + '\n' + '\n'.join(aliases) + '\n' + end
    if start in manifest:
        before, rest = manifest.split(start, 1)
        _, after = rest.split(end, 1)
        manifest = before + generated + after
    else:
        anchor = '        <activity\n            android:name=".TempActivity"'
        assert anchor in manifest
        manifest = manifest.replace(anchor, generated + '\n\n' + anchor, 1)
    write(manifest_path, manifest)
    write(OUT / 'source/catalog.json', json.dumps(metadata, indent=2) + '\n')
    print('Packaged 16 high-resolution designed icons from 8 dark/light masters; generated adaptive descriptors and monochrome vectors.')


def package():
    OUT.mkdir(parents=True, exist_ok=True)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    for style in STYLES:
        for mode in ['dark', 'light']:
            variant = f'{style}_{mode}'
            image = Image.open(ASSETS / f'brand_{variant}.png').convert('RGBA')
            image.save(OUT / f'{variant}.ico', sizes=[(s, s) for s in sizes])
    for mode, suffix in [('dark', ''), ('light', '_light')]:
        image = Image.open(ASSETS / f'brand_official_{mode}.png')
        image.save(ASSETS / f'icon{suffix}.png')
        image.save(ASSETS / f'icon{suffix}.ico', sizes=[(s, s) for s in sizes])
    (ROOT / 'windows/runner/resources/app_icon.ico').write_bytes((ASSETS / 'icon.ico').read_bytes())
    for size in [16, 32, 64, 128, 256, 512, 1024]:
        Image.open(ASSETS / 'icon.png').resize((size, size), Image.Resampling.LANCZOS).save(ROOT / f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png')
    base = Image.open(BUILD / 'status.png').convert('RGBA')
    for color in ['white', 'black']:
        status = Image.new('RGBA', base.size, color)
        status.putalpha(base.getchannel('A'))
        status.save(ASSETS / f'icon_{color}.png')
        status.save(ASSETS / f'icon_{color}.ico', sizes=[(s, s) for s in sizes])
        for size in [16, 20, 24, 32, 48]:
            status.resize((size, size), Image.Resampling.LANCZOS).save(OUT / f'status_{color}_{size}.png')
        stopped = status.copy()
        # Disconnected uses an outline F, preserving status without colour.
        from PIL import ImageFilter
        alpha = status.getchannel('A')
        stopped.putalpha(ImageChops.subtract(alpha, alpha.filter(ImageFilter.MinFilter(101))))
        stopped.save(ASSETS / f'tray_{color}_stopped.png')
        stopped.save(ASSETS / f'tray_{color}_stopped.ico', sizes=[(s, s) for s in sizes])
    (ASSETS / 'icon_template.png').write_bytes((ASSETS / 'icon_black.png').read_bytes())
    for target in ['icon_black_macOS.png', 'icon_light_macOS.png']:
        (ASSETS / target).write_bytes((ASSETS / 'icon_black.png').read_bytes())
    preview()
    files = [p for folder in [ASSETS, OUT, RES / 'drawable-xxxhdpi', RES / 'mipmap-anydpi-v26', OUT / 'source']
             for p in sorted(folder.glob('*')) if p.is_file() and p.name not in ('inventory.json', 'README.txt')
             and (folder != ASSETS or p.name.startswith(('brand_', 'status_', 'tray_', 'fluxora_', 'icon')))]
    files += list((ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'))
    files += [ROOT / 'windows/runner/resources/app_icon.ico']
    files += [RES / f'drawable/{name}.xml' for name in ['ic_launcher_monochrome', 'ic_notification_dark', 'ic_notification_light', 'ic_tile']]
    files += [RES / 'drawable-night/ic_tile.xml']
    files += list(ASSETS.glob('notification_*.svg'))
    files += [RES / f'drawable/ic_notification_{s}.xml' for s in ['flow', 'plain', 'outline']]
    inventory = {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    write(OUT / 'inventory.json', json.dumps(inventory, indent=2, ensure_ascii=False) + '\n')
    print(f'Packaged icons, ICOs, Android layers, macOS assets, preview; {len(inventory)} inventory entries.')


def preview():
    canvas = Image.new('RGB', (1600, 1120), '#08172d')
    draw = ImageDraw.Draw(canvas)
    font_path = Path('C:/Windows/Fonts/msyh.ttc')
    font = ImageFont.truetype(str(font_path), 25) if font_path.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(font_path), 20) if font_path.exists() else font
    for dark in (True, False):
        offset = 0 if dark else 445
        draw.rectangle((0, offset, 1600, offset + 445), fill='#08172d' if dark else '#eef6ff')
        draw.text((40, offset + 18), 'Fluxora / 图标深色版' if dark else 'Fluxora / 图标浅色版', fill='#cef7ff' if dark else '#124270', font=font)
        for i, (style, name) in enumerate(zip(STYLES, NAMES)):
            x, y = 58 + i % 4 * 390, offset + 75 + i // 4 * 182
            img = Image.open(ASSETS / f'brand_{style}_{"dark" if dark else "light"}.png').resize((132, 132), Image.Resampling.LANCZOS)
            canvas.paste(img, (x, y), img)
            draw.text((x + 152, y + 45), name, font=font, fill='#f2f8ff' if dark else '#17324d')
            draw.text((x + 152, y + 83), style, font=small, fill='#91b6d4' if dark else '#4c6d8c')
    draw.text((40, 910), '专用单色 F / 16 · 20 · 24 · 32 · 48 px   |   QS: ACTIVE / INACTIVE / UNAVAILABLE', font=small, fill='#cef7ff')
    for i, size in enumerate([16, 20, 24, 32, 48]):
        img = Image.open(OUT / f'status_white_{size}.png')
        canvas.paste(img, (60 + i * 88, 970), img)
    for i, (label, color) in enumerate([('已连接', '#075eae'), ('未连接', '#334155'), ('正在切换', '#202a3b')]):
        x = 570 + i * 320
        draw.rounded_rectangle((x, 960, x + 270, 1040), 32, fill=color)
        img = Image.open(OUT / 'status_white_24.png')
        canvas.paste(img, (x + 24, 987), img)
        draw.text((x + 70, 985), label, font=font, fill='#ffffff' if i != 2 else '#8a9aae')
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / 'preview.png')


def check():
    hashes = set()
    for style in STYLES:
        for mode in ['dark', 'light']:
            variant = f'{style}_{mode}'
            image = Image.open(ASSETS / f'brand_{variant}.png')
            assert image.size == (1024, 1024), variant
            hashes.add(hashlib.sha256(image.tobytes()).hexdigest())
            pair = Image.open(OUT / f'source/{style}_pair.png').convert('RGBA')
            expected = icon_cell(pair, mode == 'dark').resize((1024,1024), Image.Resampling.LANCZOS)
            assert expected.tobytes() == image.tobytes(), 'Export must match the selected master'
            with Image.open(ASSETS / f'brand/brand_{variant}.webp') as runtime_icon:
                assert runtime_icon.size == image.size and runtime_icon.tobytes() == image.tobytes(), variant
            fg = Image.open(RES / f'drawable-xxxhdpi/brand_{variant}_foreground.png')
            assert fg.size == (432,432)
            assert fg.getchannel('A').getbbox()[0] >= 72, 'Adaptive foreground must keep its 18dp inset'
            ET.parse(RES / f'mipmap-anydpi-v26/brand_{variant}.xml')
            assert Image.open(OUT / f'{variant}.ico').ico.sizes() == {(s,s) for s in [16,24,32,48,64,128,256]}
    assert len(hashes) == 16, 'Each icon needs its own colouring'
    mono = ET.parse(RES / 'drawable/ic_launcher_monochrome.xml')
    android = '{http://schemas.android.com/apk/res/android}'
    group = mono.find('group')
    scale, offset = float(group.attrib[android+'scaleX']), float(group.attrib[android+'translateX'])
    for path in group.findall('path'):
        points = [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', path.attrib[android+'pathData'])]
        # A Bezier lies inside its control-point hull, hence inside this safe circle.
        assert all(math.hypot(x*scale+offset-54, y*scale+offset-54) < 33
                   for x,y in zip(points[::2], points[1::2]))
    for mode in ['white', 'black']:
        image = Image.open(ASSETS / f'icon_{mode}.png').convert('RGBA')
        visible = [image.getpixel((x, y)) for y in range(image.height) for x in range(image.width) if image.getpixel((x, y))[3] > 0]
        assert all(p[:3] == ((255,255,255) if mode == 'white' else (0,0,0)) for p in visible)
        assert image.getpixel((0,0))[3] == 0
    manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml')
    ns = '{http://schemas.android.com/apk/res/android}'
    aliases = manifest.findall('.//activity-alias')
    assert len(aliases) == 16, len(aliases)  # two legacy names + fourteen new variants
    for node in manifest.findall('.//*[@' + ns + 'icon]'):
        resource = node.attrib[ns + 'icon']
        if resource.startswith('@mipmap/'):
            assert (RES / f'mipmap-anydpi-v26/{resource[8:]}.xml').exists(), resource
    notification_hashes = set()
    for style in ['flow', 'plain', 'outline']:
        path = RES / f'drawable/ic_notification_{style}.xml'
        ET.parse(path)
        colours = set(re.findall(r'#[0-9A-Fa-f]{8}', path.read_text()))
        assert colours <= {'#FFFFFFFF', '#00000000'}, 'Small icons must remain monochrome alpha masks'
        notification_hashes.add(hashlib.sha256(path.read_bytes()).hexdigest())
        ET.parse(ASSETS / f'notification_{style}.svg')
    assert len(notification_hashes) == 3
    for folder in ['values', 'values-night', 'values-v27', 'values-night-v27']:
        styles = (RES / folder / 'styles.xml').read_text(encoding='utf-8')
        assert 'splash_text_' not in styles and '@mipmap/brand_official_' in styles
    inventory = json.loads((OUT / 'inventory.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h for p,h in inventory.items())
    print('PASS: 16 distinct master-matched exports, adaptive padding, 7-size ICOs, monochrome alpha, aliases, hashes.')


if __name__ == '__main__':
    {'sources': sources, 'package': package, 'check': check}[sys.argv[1]]()
