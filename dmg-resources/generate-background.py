#!/usr/bin/env python3
"""
Generate a beautiful DMG background image for Luzia Universal Typo Correcter.
Requires: pip install Pillow
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

# DMG window dimensions (standard macOS installer look)
WIDTH = 660
HEIGHT = 400

# Colors - elegant dark gradient
BG_TOP = (45, 52, 64)      # Dark blue-gray
BG_BOTTOM = (28, 32, 40)   # Darker
ARROW_COLOR = (255, 255, 255, 180)  # Semi-transparent white
TEXT_COLOR = (180, 185, 195)  # Light gray

def create_gradient(width, height, top_color, bottom_color):
    """Create a vertical gradient."""
    img = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(img)

    for y in range(height):
        ratio = y / height
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    return img

def draw_arrow(draw, start_x, end_x, y, color, thickness=3):
    """Draw a stylish arrow pointing right."""
    # Main line
    draw.line([(start_x, y), (end_x - 15, y)], fill=color, width=thickness)

    # Arrowhead
    arrow_size = 12
    points = [
        (end_x, y),  # Tip
        (end_x - arrow_size, y - arrow_size // 2),  # Top
        (end_x - arrow_size, y + arrow_size // 2),  # Bottom
    ]
    draw.polygon(points, fill=color)

def draw_dashed_arrow(img, start_x, end_x, y, color):
    """Draw a dashed arrow with smooth anti-aliasing."""
    draw = ImageDraw.Draw(img, 'RGBA')

    dash_length = 12
    gap_length = 8
    x = start_x

    while x < end_x - 30:
        segment_end = min(x + dash_length, end_x - 30)
        draw.line([(x, y), (segment_end, y)], fill=color, width=3)
        x += dash_length + gap_length

    # Arrowhead (larger, more visible)
    arrow_size = 16
    points = [
        (end_x - 10, y),  # Tip
        (end_x - 10 - arrow_size, y - arrow_size * 0.6),  # Top
        (end_x - 10 - arrow_size, y + arrow_size * 0.6),  # Bottom
    ]
    draw.polygon(points, fill=color)

def main():
    # Create gradient background
    img = create_gradient(WIDTH, HEIGHT, BG_TOP, BG_BOTTOM)
    draw = ImageDraw.Draw(img, 'RGBA')

    # Icon positions (these should match the AppleScript icon positions)
    # App icon at ~140px from left, Applications at ~520px from left
    app_icon_x = 140
    apps_icon_x = 520
    icon_y = 180  # Vertical center for icons

    # Draw the arrow between icon positions
    arrow_y = icon_y + 5
    draw_dashed_arrow(img, app_icon_x + 60, apps_icon_x - 60, arrow_y, ARROW_COLOR)

    # Add subtle instruction text at the bottom
    try:
        # Try to use SF Pro or Helvetica
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
    except:
        font = ImageFont.load_default()

    text = "Drag to Applications folder to install"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = (WIDTH - text_width) // 2
    text_y = HEIGHT - 50

    draw.text((text_x, text_y), text, fill=TEXT_COLOR, font=font)

    # Add app name at top
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except:
        title_font = font

    title = "Luzia Universal Typo Correcter"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = bbox[2] - bbox[0]
    title_x = (WIDTH - title_width) // 2

    draw.text((title_x, 35), title, fill=(255, 255, 255, 220), font=title_font)

    # Save the image
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "dmg-background.png")

    # Save as PNG
    img.save(output_path, "PNG")

    # Also save @2x version for Retina displays
    img_2x = create_gradient(WIDTH * 2, HEIGHT * 2, BG_TOP, BG_BOTTOM)
    draw_2x = ImageDraw.Draw(img_2x, 'RGBA')

    # Scale up positions
    app_icon_x_2x = 280
    apps_icon_x_2x = 1040
    icon_y_2x = 360
    arrow_y_2x = icon_y_2x + 10

    # Draw larger arrow for 2x
    draw_dashed_arrow_2x(img_2x, app_icon_x_2x + 120, apps_icon_x_2x - 120, arrow_y_2x, ARROW_COLOR)

    try:
        font_2x = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
        title_font_2x = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 40)
    except:
        font_2x = ImageFont.load_default()
        title_font_2x = font_2x

    # Text at bottom
    bbox = draw_2x.textbbox((0, 0), text, font=font_2x)
    text_width = bbox[2] - bbox[0]
    draw_2x.text(((WIDTH * 2 - text_width) // 2, HEIGHT * 2 - 100), text, fill=TEXT_COLOR, font=font_2x)

    # Title at top
    bbox = draw_2x.textbbox((0, 0), title, font=title_font_2x)
    title_width = bbox[2] - bbox[0]
    draw_2x.text(((WIDTH * 2 - title_width) // 2, 70), title, fill=(255, 255, 255, 220), font=title_font_2x)

    output_path_2x = os.path.join(script_dir, "dmg-background@2x.png")
    img_2x.save(output_path_2x, "PNG")

    print(f"Created: {output_path}")
    print(f"Created: {output_path_2x}")
    print(f"Dimensions: {WIDTH}x{HEIGHT} (1x), {WIDTH*2}x{HEIGHT*2} (2x)")

def draw_dashed_arrow_2x(img, start_x, end_x, y, color):
    """Draw a dashed arrow for 2x resolution."""
    draw = ImageDraw.Draw(img, 'RGBA')

    dash_length = 24
    gap_length = 16
    x = start_x

    while x < end_x - 60:
        segment_end = min(x + dash_length, end_x - 60)
        draw.line([(x, y), (segment_end, y)], fill=color, width=6)
        x += dash_length + gap_length

    # Arrowhead
    arrow_size = 32
    points = [
        (end_x - 20, y),
        (end_x - 20 - arrow_size, y - arrow_size * 0.6),
        (end_x - 20 - arrow_size, y + arrow_size * 0.6),
    ]
    draw.polygon(points, fill=color)

if __name__ == "__main__":
    main()
