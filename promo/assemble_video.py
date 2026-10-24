"""Assembles the final Opal promo video from 60fps clips, synthesized beat,
and Material 3 pill badges / title cards.
"""
import os, pathlib, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

PROMO_DIR = pathlib.Path('/home/melissa/.local/state/opal/staging/promo')
CLIPS_DIR = pathlib.Path('/home/melissa/.local/state/opal/artifacts/promo/clips')
OUT_DIR = pathlib.Path('/home/melissa/.local/state/opal/artifacts/promo')
OVERLAYS_DIR = OUT_DIR / 'overlays'
OVERLAYS_DIR.mkdir(parents=True, exist_ok=True)

FONT_PATH = '/usr/local/share/fonts/g/GoogleSansFlex_VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf'
if not os.path.exists(FONT_PATH):
    FONT_PATH = '/usr/share/fonts/inter/Inter.ttc'

def create_badge(filename, tag, title, width=1920, height=1080):
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    font_bold = ImageFont.truetype(FONT_PATH, 28)
    font_regular = ImageFont.truetype(FONT_PATH, 24)
    
    tag_text = tag.upper()
    title_text = title
    
    # Calculate dimensions
    tag_bbox = font_bold.getbbox(tag_text)
    title_bbox = font_regular.getbbox(title_text)
    
    tag_w = tag_bbox[2] - tag_bbox[0]
    title_w = title_bbox[2] - title_bbox[0]
    
    pad_x = 24
    pad_y = 14
    gap = 18
    pill_w = pad_x * 2 + tag_w + gap + title_w + 12
    pill_h = 56
    
    # Position: top-left corner
    x0 = 48
    y0 = 48
    x1 = x0 + pill_w
    y1 = y0 + pill_h
    r = pill_h // 2
    
    # Pill shadow
    draw.rounded_rectangle([x0+2, y0+4, x1+2, y1+4], radius=r, fill=(0, 0, 0, 110))
    # Pill surface: dark frosted glass (Material 3 Surface Container Highest)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=(28, 32, 38, 225), outline=(255, 255, 255, 45), width=1)
    
    # Accent dot
    dot_r = 5
    dot_cx = x0 + pad_x + dot_r
    dot_cy = y0 + pill_h // 2
    draw.ellipse([dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r], fill=(138, 180, 248, 255))
    
    # Tag text (Accent colored)
    tx = dot_cx + dot_r + 10
    ty = y0 + (pill_h - (tag_bbox[3] - tag_bbox[1])) // 2 - 2
    draw.text((tx, ty), tag_text, font=font_bold, fill=(138, 180, 248, 255))
    
    # Divider
    div_x = tx + tag_w + gap // 2
    draw.line([div_x, y0 + 16, div_x, y1 - 16], fill=(255, 255, 255, 50), width=1)
    
    # Title text (White/On-surface)
    draw.text((div_x + gap // 2, ty + 2), title_text, font=font_regular, fill=(240, 242, 245, 255))
    
    out_file = OVERLAYS_DIR / filename
    img.save(out_file)
    return out_file

def create_outro_card(filename, width=1920, height=1080):
    img = Image.new('RGBA', (width, height), (14, 16, 20, 255))
    draw = ImageDraw.Draw(img)
    
    font_hero = ImageFont.truetype(FONT_PATH, 110)
    font_sub = ImageFont.truetype(FONT_PATH, 34)
    font_repo = ImageFont.truetype(FONT_PATH, 26)
    
    # Center text
    hero = "OPAL"
    sub = "Material 3 Expressive Linux Shell"
    repo = "github.com/kriscrossapplesauce2004/opal-shell"
    
    h_bbox = font_hero.getbbox(hero)
    s_bbox = font_sub.getbbox(sub)
    r_bbox = font_repo.getbbox(repo)
    
    h_w = h_bbox[2] - h_bbox[0]
    s_w = s_bbox[2] - s_bbox[0]
    r_w = r_bbox[2] - r_bbox[0]
    
    cy = height // 2 - 40
    
    # Glow behind hero
    for radius in range(90, 10, -10):
        alpha = int(12 * (1.0 - radius / 90.0))
        draw.ellipse([width//2 - radius*2.5, cy - radius, width//2 + radius*2.5, cy + radius], fill=(66, 133, 244, alpha))
        
    draw.text(((width - h_w) // 2, cy - 80), hero, font=font_hero, fill=(255, 255, 255, 255))
    draw.text(((width - s_w) // 2, cy + 50), sub, font=font_sub, fill=(180, 205, 245, 255))
    
    # Pill for repo link
    rp_w = r_w + 48
    rp_h = 48
    rx0 = (width - rp_w) // 2
    ry0 = cy + 130
    draw.rounded_rectangle([rx0, ry0, rx0 + rp_w, ry0 + rp_h], radius=rp_h//2, fill=(35, 40, 50, 255), outline=(138, 180, 248, 120), width=1)
    draw.text(((width - r_w) // 2, ry0 + 10), repo, font=font_repo, fill=(138, 180, 248, 255))
    
    out_file = OVERLAYS_DIR / filename
    img.save(out_file)
    return out_file

def assemble():
    print("Generating overlays...")
    b1 = create_badge('badge1.png', 'Desktop', 'Fluid Workspace & Expressive Launch')
    b2 = create_badge('badge2.png', 'Multitasking', 'Instant Glass Switcher & Window Snapping')
    b3 = create_badge('badge3.png', 'Customization', 'Dynamic Material 3 Colors & Themes')
    b4 = create_badge('badge4.png', 'Intelligence', 'Contextual Shelf, Media & Assistant')
    b5 = create_badge('badge5.png', 'Console Mode', 'Steam Deck-Class Quick Access Overlay')
    b6 = create_badge('badge6.png', 'Mobile Mode', 'Smooth Phone Convergence')
    outro = OVERLAYS_DIR / 'outro.png'
    
    soundtrack = OUT_DIR / 'soundtrack.wav'
    final_video = OUT_DIR / 'opal-showcase.mp4'
    
    print("Cutting and compositing segments with ffmpeg...")
    
    # Filter complex timeline:
    # Seg 1: 0.00 to 3.75s (desktop)
    # Seg 2: 3.75 to 9.38s (switcher)
    # Seg 3: 9.38 to 15.00s (style)
    # Seg 4: 15.00 to 20.62s (panels)
    # Seg 5: 20.62 to 25.31s (console)
    # Seg 6: 25.31 to 28.59s (phone with blurred background)
    # Seg 7: 28.59 to 30.00s (outro)
    
    cmd = [
        'ffmpeg', '-y', '-v', 'warning',
        '-ss', '1.0', '-t', '3.75', '-i', str(CLIPS_DIR / 'scene1-desktop.mkv'),
        '-ss', '0.8', '-t', '5.63', '-i', str(CLIPS_DIR / 'scene2-switcher.mkv'),
        '-ss', '1.2', '-t', '5.62', '-i', str(CLIPS_DIR / 'scene3-style.mkv'),
        '-ss', '0.8', '-t', '5.62', '-i', str(CLIPS_DIR / 'scene4-panels.mkv'),
        '-ss', '1.0', '-t', '4.69', '-i', str(CLIPS_DIR / 'scene5-console.mkv'),
        '-ss', '0.6', '-t', '3.28', '-i', str(CLIPS_DIR / 'scene6-phone.mkv'),
        '-loop', '1', '-t', '1.41', '-i', str(outro),
        '-loop', '1', '-i', str(b1),
        '-loop', '1', '-i', str(b2),
        '-loop', '1', '-i', str(b3),
        '-loop', '1', '-i', str(b4),
        '-loop', '1', '-i', str(b5),
        '-loop', '1', '-i', str(b6),
        '-i', str(soundtrack),
        '-filter_complex',
        '[0:v]scale=1920:1080,setsar=1,fps=60[v0raw]; [v0raw][7:v]overlay=0:0:shortest=1[v0];'
        '[1:v]scale=1920:1080,setsar=1,fps=60[v1raw]; [v1raw][8:v]overlay=0:0:shortest=1[v1];'
        '[2:v]scale=1920:1080,setsar=1,fps=60[v2raw]; [v2raw][9:v]overlay=0:0:shortest=1[v2];'
        '[3:v]scale=1920:1080,setsar=1,fps=60[v3raw]; [v3raw][10:v]overlay=0:0:shortest=1[v3];'
        '[4:v]scale=1920:1080,setsar=1,fps=60[v4raw]; [v4raw][11:v]overlay=0:0:shortest=1[v4];'
        # Phone: create ambient blurred 1080p background, place phone in center
        '[5:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=25:5,eq=brightness=-0.35,fps=60[pbg];'
        '[5:v]scale=-1:980,fps=60[pfg];'
        '[pbg][pfg]overlay=(W-w)/2:(H-h)/2,setsar=1[v5composed];'
        '[v5composed][12:v]overlay=0:0:shortest=1[v5];'
        '[6:v]scale=1920:1080,fade=t=out:st=1.0:d=0.4:color=black,fps=60[v6];'
        '[v0][v1][v2][v3][v4][v5][v6]concat=n=7:v=1:a=0[vfinal];'
        '[13:a]afade=t=in:st=0:d=0.3,afade=t=out:st=29.2:d=0.8[afinal]',
        '-map', '[vfinal]', '-map', '[afinal]',
        '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '256k',
        '-movflags', '+faststart',
        str(final_video)
    ]
    
    subprocess.run(cmd, check=True)
    print(f"\nPROMO VIDEO SUCCESSFULLY GENERATED: {final_video}")
    size = final_video.stat().st_size / (1024*1024)
    print(f"File size: {size:.2f} MB")

if __name__ == '__main__':
    assemble()
