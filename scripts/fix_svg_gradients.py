#!/usr/bin/env python3
"""
Process SVG files to remove gradients and use solid colors
This is needed because Xcode Assets doesn't support SVG gradients
"""

import os
import re
import json

ASSETS_PATH = "/Users/mihai/Developer/cycle.app-frontend-swift/CycleApp/Resources/Assets.xcassets/Symptoms"

# App's accent color (magenta/pink from the design)
SOLID_COLOR = "#B63AB4"

def process_svg(svg_content):
    """
    Remove gradients and replace fill references with solid color
    """
    # Remove defs section with gradients
    svg_content = re.sub(r'<defs>.*?</defs>', '', svg_content, flags=re.DOTALL)
    
    # Replace url(#...) gradient references with solid color
    svg_content = re.sub(r'fill="url\(#[^)]+\)"', f'fill="{SOLID_COLOR}"', svg_content)
    
    # Also handle any remaining fill="none"
    # (keep fill="none" as is, it's intentional for stroke-only paths)
    
    # Clean up any extra whitespace
    svg_content = re.sub(r'\n\s*\n', '\n', svg_content)
    
    return svg_content

def process_all_svgs():
    """Process all SVG files in the Symptoms folder"""
    processed = 0
    errors = 0
    
    for item in os.listdir(ASSETS_PATH):
        if item.endswith('.imageset'):
            imageset_path = os.path.join(ASSETS_PATH, item)
            
            # Find SVG file in imageset
            for file in os.listdir(imageset_path):
                if file.endswith('.svg'):
                    svg_path = os.path.join(imageset_path, file)
                    
                    try:
                        # Read SVG
                        with open(svg_path, 'r') as f:
                            content = f.read()
                        
                        # Check if it has gradients
                        if 'linearGradient' in content or 'radialGradient' in content:
                            print(f"Processing {item}...")
                            
                            # Process SVG
                            new_content = process_svg(content)
                            
                            # Write back
                            with open(svg_path, 'w') as f:
                                f.write(new_content)
                            
                            print(f"  ✓ Gradients removed")
                            processed += 1
                        else:
                            print(f"  - {item}: No gradients found")
                    
                    except Exception as e:
                        print(f"  ✗ Error processing {item}: {e}")
                        errors += 1
    
    print()
    print(f"Done! Processed: {processed}, Errors: {errors}")

if __name__ == "__main__":
    print("Removing gradients from SVG icons...")
    print(f"Using solid color: {SOLID_COLOR}")
    print()
    process_all_svgs()
