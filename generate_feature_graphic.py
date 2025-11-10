#!/usr/bin/env python3
"""
Generate a feature graphic for the PocketPilot app for Google Play Store.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_feature_graphic():
    # Create a new image with the required dimensions for Google Play (1024x500)
    width, height = 1024, 500
    background_color = (0, 150, 136)  # #009688 teal color
    accent_color = (255, 255, 255)    # White
    
    # Create the image
    img = Image.new('RGB', (width, height), background_color)
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fallback to default if not available
    try:
        # Try to use a system font
        font_large = ImageFont.truetype("arial.ttf", 80)
        font_medium = ImageFont.truetype("arial.ttf", 40)
        font_small = ImageFont.truetype("arial.ttf", 30)
    except:
        # Fallback to default font
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Draw the app title
    title = "PocketPilot"
    # Calculate text size for centering
    bbox = draw.textbbox((0, 0), title, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) // 2
    y = height // 4
    
    # Draw title with shadow effect
    draw.text((x+2, y+2), title, fill=(0, 0, 0), font=font_large)
    draw.text((x, y), title, fill=accent_color, font=font_large)
    
    # Draw subtitle
    subtitle = "Your Personal Financial Guide"
    bbox = draw.textbbox((0, 0), subtitle, font=font_medium)
    text_width = bbox[2] - bbox[0]
    x = (width - text_width) // 2
    y = height // 4 + 100
    
    draw.text((x+1, y+1), subtitle, fill=(0, 0, 0), font=font_medium)
    draw.text((x, y), subtitle, fill=accent_color, font=font_medium)
    
    # Draw feature highlights
    features = [
        "Smart Budgeting",
        "Expense Tracking", 
        "Financial Insights",
        "Secure & Private"
    ]
    
    # Draw decorative elements
    # Draw some circles as decorative elements
    for i in range(5):
        x_pos = 100 + i * 200
        y_pos = height - 150
        radius = 30
        draw.ellipse([x_pos-radius, y_pos-radius, x_pos+radius, y_pos+radius], 
                    outline=accent_color, width=2)
    
    # Draw some lines as decorative elements
    for i in range(3):
        y_pos = 100 + i * 50
        draw.line([50, y_pos, 200, y_pos], fill=accent_color, width=2)
    
    # Save the image
    output_path = "promotional-assets/feature-graphic.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path)
    
    print(f"Feature graphic created successfully at {output_path}")
    print("Dimensions: 1024x500 pixels")
    print("Background color: #009688 (Teal)")
    print("Text color: White")

if __name__ == "__main__":
    create_feature_graphic()