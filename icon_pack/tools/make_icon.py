#!/usr/bin/env python3
"""يولّد أيقونة Open Gate لأندرويد: Adaptive + Legacy + Monochrome.

التشغيل من جذر المستودع:  python tools/make_icon.py
- إن وُجد assets/icon/foreground.png (1024x1024 بخلفية شفافة) يُستخدم بدل الرسم الافتراضي.
- يكتب الأيقونات داخل android/app/src/main/res (أو داخل --root إن حُدّد).
"""
import argparse
import math
import os

from PIL import Image, ImageChops, ImageDraw

S = 1024                      # مقاس الإطار الأساسي
SS = 2                        # تكبير داخلي لنعومة الحواف
BG = (11, 11, 15)             # #0B0B0F
BG_HEX = '#0B0B0F'
GOLD_TOP = (244, 216, 124)
GOLD_BOT = (184, 146, 42)
SAFE_K = 0.84                 # تصغير المحتوى ليبقى داخل منطقة الأمان للأيقونة التكيفية


def vgrad(size, top, bot):
    w, h = size
    col = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return col.resize((w, h))


def arch(size, x0, y0, x1, y1):
    """قوس: نصف دائرة في الأعلى ومستطيل تحتها."""
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    r = (x1 - x0) // 2
    d.pieslice([x0, y0, x1, y0 + 2 * r], 180, 360, fill=255)
    d.rectangle([x0, y0 + r, x1, y1], fill=255)
    return m


def draw_foreground():
    """بوابة ذهبية بقوس، وشمس تشرق من داخلها، فوق قاعدة."""
    W = S * SS

    def sc(v):
        return int(v * SS)

    outer = arch((W, W), sc(292), sc(236), sc(732), sc(770))
    inner = arch((W, W), sc(346), sc(290), sc(678), sc(770))
    shape = ImageChops.subtract(outer, inner)
    d = ImageDraw.Draw(shape)

    # القاعدة
    d.rounded_rectangle([sc(252), sc(770), sc(772), sc(816)], radius=sc(14), fill=255)

    # الشمس (نصف دائرة) تشرق من خط القاعدة داخل فتحة البوابة
    cx, cy, r = sc(512), sc(770), sc(96)
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=255)

    # الأشعة
    for ang, end in ((30, 165), (60, 188), (90, 188), (120, 188), (150, 165)):
        a = math.radians(ang)
        x0, y0 = cx + sc(128) * math.cos(a), cy - sc(128) * math.sin(a)
        x1, y1 = cx + sc(end) * math.cos(a), cy - sc(end) * math.sin(a)
        w = sc(22)
        d.line([(x0, y0), (x1, y1)], fill=255, width=w)
        for (px, py) in ((x0, y0), (x1, y1)):
            d.ellipse([px - w / 2, py - w / 2, px + w / 2, py + w / 2], fill=255)

    gold = vgrad((W, W), GOLD_TOP, GOLD_BOT)
    fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    fg.paste(gold, (0, 0), shape)
    return fg.resize((S, S), Image.LANCZOS)


def fit(img, k):
    """يكبّر/يصغّر المحتوى حول المركز مع الإبقاء على الإطار S×S."""
    n = max(1, int(S * k))
    scaled = img.resize((n, n), Image.LANCZOS)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if n <= S:
        out.paste(scaled, ((S - n) // 2, (S - n) // 2), scaled)
    else:
        off = (n - S) // 2
        out.paste(scaled.crop((off, off, off + S, off + S)), (0, 0))
    return out


def rounded_mask(size, radius_ratio):
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_ratio), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def build(root, foreground_path):
    if os.path.exists(foreground_path):
        fg = Image.open(foreground_path).convert('RGBA').resize((S, S), Image.LANCZOS)
        print('استخدام الأيقونة المخصّصة:', foreground_path)
    else:
        fg = draw_foreground()
        os.makedirs(os.path.dirname(foreground_path), exist_ok=True)
        fg.save(foreground_path)
        print('رُسمت الأيقونة الافتراضية وحُفظت في', foreground_path)

    adaptive_fg = fit(fg, SAFE_K)                      # للأيقونة التكيفية والأحادية اللون
    legacy = Image.new('RGBA', (S, S), BG + (255,))   # للأجهزة القديمة
    legacy.alpha_composite(fit(fg, 1.1))
    legacy.putalpha(rounded_mask(S, 0.22))

    res = os.path.join(root, 'android', 'app', 'src', 'main', 'res')
    dens = {'mdpi': (48, 108), 'hdpi': (72, 162), 'xhdpi': (96, 216),
            'xxhdpi': (144, 324), 'xxxhdpi': (192, 432)}
    for name, (legacy_px, fg_px) in dens.items():
        d = os.path.join(res, f'mipmap-{name}')
        os.makedirs(d, exist_ok=True)
        legacy.resize((legacy_px, legacy_px), Image.LANCZOS).save(os.path.join(d, 'ic_launcher.png'))
        adaptive_fg.resize((fg_px, fg_px), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_foreground.png'))

    any_dir = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(any_dir, exist_ok=True)
    with open(os.path.join(any_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')

    vals = os.path.join(res, 'values')
    os.makedirs(vals, exist_ok=True)
    with open(os.path.join(vals, 'ic_launcher_background.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    <color name="ic_launcher_background">{BG_HEX}</color>\n</resources>\n')

    # أيقونة متجر Google Play (512x512، مربعة بلا زوايا مقصوصة)
    store = Image.new('RGBA', (S, S), BG + (255,))
    store.alpha_composite(fit(fg, 1.0))
    icon_dir = os.path.dirname(foreground_path)
    store.convert('RGB').resize((512, 512), Image.LANCZOS).save(os.path.join(icon_dir, 'play_store_512.png'))
    return fg, adaptive_fg, legacy


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default='.')
    args = ap.parse_args()
    build(args.root, os.path.join(args.root, 'assets', 'icon', 'foreground.png'))
    print('تم توليد الأيقونات.')
