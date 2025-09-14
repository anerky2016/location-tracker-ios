#!/usr/bin/env python3
"""
Simple script to generate placeholder app icons for iOS Location Tracker
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, filename):
    """Create a simple app icon with the specified size"""
    # Create a new image with a blue background
    img = Image.new('RGB', (size, size), color='#007AFF')
    draw = ImageDraw.Draw(img)
    
    # Add a white circle in the center
    margin = size // 8
    draw.ellipse([margin, margin, size-margin, size-margin], fill='white')
    
    # Add a location pin symbol (simple triangle)
    pin_size = size // 4
    pin_x = size // 2
    pin_y = size // 2 + pin_size // 4
    
    # Draw a simple location pin
    points = [
        (pin_x, pin_y - pin_size//2),  # Top point
        (pin_x - pin_size//3, pin_y + pin_size//4),  # Bottom left
        (pin_x + pin_size//3, pin_y + pin_size//4)   # Bottom right
    ]
    draw.polygon(points, fill='#007AFF')
    
    # Add a small circle at the bottom
    circle_size = pin_size // 3
    draw.ellipse([pin_x - circle_size//2, pin_y + pin_size//4 - circle_size//2, 
                  pin_x + circle_size//2, pin_y + pin_size//4 + circle_size//2], 
                 fill='#007AFF')
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Created {filename} ({size}x{size})")

def main():
    """Generate all required app icons"""
    icon_dir = "LocationTracker/Assets.xcassets/AppIcon.appiconset"
    
    # Define all the required icon sizes
    icons = [
        (40, "Icon-App-20x20@2x.png"),      # iPhone 20x20@2x
        (60, "Icon-App-20x20@3x.png"),      # iPhone 20x20@3x
        (58, "Icon-App-29x29@2x.png"),      # iPhone 29x29@2x
        (87, "Icon-App-29x29@3x.png"),      # iPhone 29x29@3x
        (80, "Icon-App-40x40@2x.png"),      # iPhone 40x40@2x
        (120, "Icon-App-40x40@3x.png"),     # iPhone 40x40@3x
        (120, "Icon-App-60x60@2x.png"),     # iPhone 60x60@2x (This is the critical 120x120!)
        (180, "Icon-App-60x60@3x.png"),     # iPhone 60x60@3x
        (20, "Icon-App-20x20@1x.png"),      # iPad 20x20@1x
        (40, "Icon-App-20x20@2x.png"),      # iPad 20x20@2x
        (29, "Icon-App-29x29@1x.png"),      # iPad 29x29@1x
        (58, "Icon-App-29x29@2x.png"),      # iPad 29x29@2x
        (40, "Icon-App-40x40@1x.png"),      # iPad 40x40@1x
        (80, "Icon-App-40x40@2x.png"),      # iPad 40x40@2x
        (152, "Icon-App-76x76@2x.png"),     # iPad 76x76@2x
        (167, "Icon-App-83.5x83.5@2x.png"), # iPad 83.5x83.5@2x
        (1024, "Icon-App-1024x1024@1x.png") # App Store 1024x1024
    ]
    
    # Create each icon
    for size, filename in icons:
        filepath = os.path.join(icon_dir, filename)
        create_icon(size, filepath)
    
    print("\n✅ All app icons generated successfully!")
    print("📱 The critical 120x120 icon (Icon-App-60x60@2x.png) has been created!")

if __name__ == "__main__":
    main()
