#!/usr/bin/env python3
"""Generates Mayari branding art: desktop wallpaper, GRUB background,
and Plymouth boot-splash images (logo + progress bar pieces)."""
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

TOP    = (26, 10, 36)     # #1a0a24
BOTTOM = (58, 13, 77)     # #3a0d4d
ACCENT = (217, 70, 239)   # #d946ef magenta
ACCENT2 = (168, 85, 247)  # #a855f7 purple

def vertical_gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h), top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r = int(top[0] + (bottom[0]-top[0])*t)
        g = int(top[1] + (bottom[1]-top[1])*t)
        b = int(top[2] + (bottom[2]-top[2])*t)
        draw.line([(0,y),(w,y)], fill=(r,g,b))
    return img

def add_accent_lines(img, seed_offset=0):
    w, h = img.size
    draw = ImageDraw.Draw(img, "RGBA")
    # thin diagonal accent lines, bottom-right, suggesting circuitry / network
    import random
    random.seed(42 + seed_offset)
    for i in range(14):
        x0 = random.randint(int(w*0.5), w)
        y0 = random.randint(int(h*0.4), h)
        length = random.randint(80, 260)
        angle = random.choice([30, -30, 45, -45, 60])
        x1 = x0 + int(length * math.cos(math.radians(angle)))
        y1 = y0 + int(length * math.sin(math.radians(angle)))
        alpha = random.randint(18, 50)
        draw.line([(x0,y0),(x1,y1)], fill=ACCENT+(alpha,), width=1)
    return img

def wordmark(draw, x, y, size, fill):
    font = ImageFont.truetype(BOLD, size)
    draw.text((x, y), "MAYARI", font=font, fill=fill)
    return font

def make_wallpaper(path, w=1920, h=1080):
    img = vertical_gradient(w, h, TOP, BOTTOM).convert("RGBA")
    img = add_accent_lines(img, 0)
    draw = ImageDraw.Draw(img, "RGBA")

    # soft glow circle behind wordmark
    glow = Image.new("RGBA", (900, 900), (0,0,0,0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([0,0,900,900], fill=ACCENT2+(60,))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img.alpha_composite(glow, (int(w*0.06)-250, int(h*0.62)-300))

    font = ImageFont.truetype(BOLD, 110)
    draw.text((int(w*0.07), int(h*0.74)), "MAYARI", font=font, fill=(240,235,250,255))
    tag_font = ImageFont.truetype(MONO, 28)
    draw.text((int(w*0.072), int(h*0.74)+128), "void-based offensive security", font=tag_font, fill=ACCENT+(220,))

    img.convert("RGB").save(path, "PNG")

def make_grub_bg(path, w=1920, h=1080):
    # Darker/plainer variant — GRUB text needs to stay readable over it
    img = vertical_gradient(w, h, (14,6,20), (34,9,46)).convert("RGBA")
    img = add_accent_lines(img, 1)
    draw = ImageDraw.Draw(img, "RGBA")
    font = ImageFont.truetype(BOLD, 64)
    draw.text((int(w*0.06), int(h*0.08)), "MAYARI", font=font, fill=(235,228,245,235))
    img.convert("RGB").save(path, "PNG")

def make_logo(path, w=640, h=200):
    img = Image.new("RGBA", (w, h), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(BOLD, 96)
    bbox = draw.textbbox((0,0), "MAYARI", font=font)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    tx, ty = (w-tw)//2, (h-th)//2 - 10
    draw.text((tx,ty), "MAYARI", font=font, fill=(240,235,250,255))
    img.save(path, "PNG")

def make_bar(path, w, h, color):
    img = Image.new("RGBA", (w,h), color)
    img.save(path, "PNG")

if __name__ == "__main__":
    import os
    out = "/home/claude/mayari-assets"
    os.makedirs(out, exist_ok=True)
    make_wallpaper(f"{out}/mayari-wallpaper.png")
    make_grub_bg(f"{out}/grub-background.png")
    make_logo(f"{out}/logo.png")
    make_bar(f"{out}/bar_track.png", 420, 6, (255,255,255,40))
    make_bar(f"{out}/bar_fill.png", 420, 6, ACCENT+(255,))
    print("done")
