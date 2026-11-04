#!/usr/bin/env python3
"""Yorunote 圖示產生腳本（可重現）。用法：python3 make_icons.py <repo_root>
輸入：brand/source/yorunote_logo_source_1254.webp（1254x1254 RGBA 點陣原稿，非向量）
輸出：Android mipmap-*（ic_launcher / _foreground / _background / _monochrome）、assets/app_icon.png、previews/
"""
import sys, os
from PIL import Image, ImageDraw, ImageChops
root = sys.argv[1]
here = os.path.join(root, 'docs/verification/yorunote-brand-v0.1/brand')
BG = (0x17, 0x28, 0x3B, 255)
src = Image.open(os.path.join(here, 'source/yorunote_logo_source_1254.webp')).convert('RGBA')
src = src.crop(src.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox())  # 裁掉多餘透明邊
W, H = src.size
def fit(img, box_px, canvas_px, dy=0):
    """把角色等比縮放為寬/高最大 box_px，置中放入透明 canvas_px 方形畫布。"""
    s = box_px / max(img.size)
    r = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    c = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    c.alpha_composite(r, ((canvas_px - r.width) // 2, (canvas_px - r.height) // 2 + dy))
    return c
def mono_of(img):
    """單色層：以輪廓為底，依亮度決定不透明度（暗線條／眼睛／衣領鏤空），只用 alpha。"""
    l = img.convert('L')
    a = img.getchannel('A')
    k = l.point(lambda v: int(max(0, min(1, (v - 70) / 90)) * 255))
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.putalpha(ImageChops.multiply(a, k))
    return out
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
res = os.path.join(root, 'android/app/src/main/res')
for d, m in dens.items():
    p = os.path.join(res, f'mipmap-{d}')
    c108 = round(108 * m)
    fg = fit(src, 64 * m, c108)            # 角色寬度 64dp，位於中央 66dp 安全圓內
    fg.save(f'{p}/ic_launcher_foreground.png')
    mono_of(fg).save(f'{p}/ic_launcher_monochrome.png')
    Image.new('RGBA', (c108, c108), BG).save(f'{p}/ic_launcher_background.png')
    # 傳統圖示 48dp：圓角方形底 + 頭像較大
    c48 = round(48 * m)
    base = Image.new('RGBA', (c48, c48), (0, 0, 0, 0))
    mask = Image.new('L', (c48, c48), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, c48 - 1, c48 - 1], radius=round(c48 * 0.22), fill=255)
    base.paste(Image.new('RGBA', (c48, c48), BG), (0, 0), mask)
    base.alpha_composite(fit(src, c48 * 0.86, c48))
    base.save(f'{p}/ic_launcher.png')
# About / Flutter 資產：1024 方形，About 會以圓形裁切
ai = Image.new('RGBA', (1024, 1024), BG)
ai.alpha_composite(fit(src, 840, 1024))
ai.save(os.path.join(root, 'assets/app_icon.png'))
# 預覽
pv = os.path.join(here, 'previews')
fg = Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher_foreground.png')
bg = Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher_background.png')
mn = Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher_monochrome.png')
full = bg.copy(); full.alpha_composite(fg)           # 432px = 108dp
def crop(img, shape):
    s = 288  # 72dp 可見區
    v = img.crop((72, 72, 72 + s, 72 + s))
    m = Image.new('L', (s, s), 0); d = ImageDraw.Draw(m)
    if shape == 'circle': d.ellipse([0, 0, s - 1, s - 1], fill=255)
    else: d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.3), fill=255)
    o = Image.new('RGBA', (s, s), (0, 0, 0, 0)); o.paste(v, (0, 0), m); return o
sheet = Image.new('RGBA', (288 * 4 + 50, 288 + 20 + 120), (236, 236, 236, 255))
x = 10
for im in [crop(full, 'circle'), crop(full, 'squircle')]:
    sheet.alpha_composite(im, (x, 10)); x += 298
mono_prev = Image.new('RGBA', (432, 432), (200, 215, 235, 255))
tint = Image.new('RGBA', (432, 432), (30, 50, 90, 255)); tint.putalpha(mn.getchannel('A'))
mono_prev.alpha_composite(tint)
sheet.alpha_composite(crop(mono_prev, 'circle'), (x, 10)); x += 298
safe = full.copy(); dd = ImageDraw.Draw(safe)
dd.ellipse([216 - 132, 216 - 132, 216 + 132, 216 + 132], outline=(255, 80, 80, 255), width=2)  # 66dp 安全圓
dd.rectangle([36, 36, 395, 395], outline=(255, 255, 0, 255), width=1)  # 72dp 可見區邊界
sheet.alpha_composite(crop(safe, 'squircle'), (x, 10))
x = 10
leg = Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher.png')
for px in (48, 32, 24):
    sheet.alpha_composite(leg.resize((px, px), Image.LANCZOS), (x, 320)); x += px + 20
x += 30
for px in (48, 32, 24):
    c = crop(full, 'circle').resize((px, px), Image.LANCZOS); sheet.alpha_composite(c, (x, 320)); x += px + 20
sheet.convert('RGB').save(os.path.join(pv, 'icon_preview.png'))
print('ok')
