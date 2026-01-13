#!/usr/bin/env python3
"""
Download Figma icons and save them to the Xcode assets folder
"""

import os
import urllib.request
import json

# Base path for assets
ASSETS_PATH = "/Users/mihai/Developer/cycle.app-frontend-swift/CycleApp/Resources/Assets.xcassets/Symptoms"

# Figma icon URLs mapped to our asset names
# Based on the Figma export from node 2261:3468

FIGMA_ICONS = {
    # Mood icons (from Figma)
    "mood_calm": "http://localhost:3845/assets/11e359b4bbdd057bb0d8ec0a66d22f31dc4084c5.svg",  # Tranquilla
    "mood_happy": "http://localhost:3845/assets/3682b269ceac891ae50686f347df661d32e1eba8.svg",  # Felice
    "mood_sensitive": "http://localhost:3845/assets/2c0b535fa096c5dbea70345c783fbe8946417e93.svg",  # Ipersensibile
    "mood_sad": "http://localhost:3845/assets/093c3f84da4927bb224c9faab0e667012fbaa977.svg",  # Triste
    "mood_apathetic": "http://localhost:3845/assets/91c718a400471205b6a778d84d85882cbac643e7.svg",  # Apatica
    "mood_tired": "http://localhost:3845/assets/f7400625191102cb981bdc7d995cc404d18c1df6.svg",  # Stanca (Group6)
    "mood_angry": "http://localhost:3845/assets/6cb5f909299ed78135156c6f0eccfb2128cd19ef.svg",  # Arrabbiata
    "mood_selfcritical": "http://localhost:3845/assets/6ac44e7646292ead537885ab092fbce644b4ae0e.svg",  # Molto autocritica
    "mood_lively": "http://localhost:3845/assets/39ab698ba8e334ebbd4ff45de82a8123c883dd07.svg",  # Vivace
    "mood_motivated": "http://localhost:3845/assets/2cecdd67be9cf7e9b97dce02a013c7c6231a11c1.svg",  # Motivata
    "mood_anxious": "http://localhost:3845/assets/89a0331c8e998d5d8090e16e972e771c76ea906c.svg",  # Ansiosa
    "mood_confident": "http://localhost:3845/assets/e45eb3aeb4e029fcd64923b624466cd7bd7f235f.svg",  # Sicura
    "mood_irritable": "http://localhost:3845/assets/799239e12dd855f12e0776b3fbde2679e13484de.svg",  # Irritabile
    "mood_emotional": "http://localhost:3845/assets/e3b0897139aa65a45b831b08c926af3877cf422b.svg",  # Emotiva
    "mood_swings": "http://localhost:3845/assets/9d1624e75091dbc1b99bd9f10bac0ab9c0a16137.svg",  # Sbalzi d'umore
    
    # Stress icons
    "stress_zero": "http://localhost:3845/assets/a5c725db7271fd642978522cafa54fec6f10178c.svg",  # Zero
    "stress_manageable": "http://localhost:3845/assets/68c3cb15b72ce1f87683ca94fa368b38a153ddeb.svg",  # Gestibile
    "stress_intense": "http://localhost:3845/assets/ee0102318c9adc4497b640a2cac947328a36ae66.svg",  # Intenso (top part)
    
    # Energy icons
    "energy_low": "http://localhost:3845/assets/9ac6a18a3ed623a177a0eefcb2f5e6d47ce3f4f3.svg",  # A terra
    "energy_normal": "http://localhost:3845/assets/a471a9d86e4863d5820b416c1adcf0fa38a89046.svg",  # Normale
    "energy_high": "http://localhost:3845/assets/eccd0f0035d21c0b2af8cf65346737996db47098.svg",  # A mille
    
    # Skin icons
    "skin_normal": "http://localhost:3845/assets/7996d8c18f9f0d707d442aa7277afe0020f51fac.svg",  # Normale
    "skin_dry": "http://localhost:3845/assets/113ec1e1073084454e6cab326f0e2c8766a722de.svg",  # Secca
    "skin_oily": "http://localhost:3845/assets/8d7693a1f4bbbbc0e699c8fc51ece0326f8d3ed6.svg",  # Lucida
    "skin_acne": "http://localhost:3845/assets/e558cc94cfb367694c8428543702fcb55c3c9dbe.svg",  # Acne (Group)
    "skin_itchy": "http://localhost:3845/assets/bd292b8bb7fa693adff8e6df38d2b315039aebfa.svg",  # Prurito
    
    # Hair icons
    "hair_normal": "http://localhost:3845/assets/69f9af32e0e1e1fa730196716b201de2dc96656f.svg",  # Normali
    "hair_shiny": "http://localhost:3845/assets/3dab127f916f04399f516ed939d74920389d8ca9.svg",  # Lucenti
    "hair_oily": "http://localhost:3845/assets/fbf00611e040c4ecb9eeb26c4f333fa6a45a5ae3.svg",  # Pesanti
    "hair_dry": "http://localhost:3845/assets/24ce340844c7b877db4658c379d45b7f58a16035.svg",  # Secchi
    "hair_sensitive": "http://localhost:3845/assets/17658ee073d92e546521ea36aad8f9d67c6e3095.svg",  # Cute sensibile
    "hair_loss": "http://localhost:3845/assets/2991d9e6531cf47b9a9c4ce98f4500cc7b4e1793.svg",  # Perdita
    
    # Sleep icons
    "sleep_peaceful": "http://localhost:3845/assets/ce9cf5687b9466fef8a10505eaa17509997c4c68.svg",  # Sereno
    "sleep_difficulty": "http://localhost:3845/assets/29943bf89b37749ae65e2b1e4485a7cedbe8a7bb.svg",  # Difficoltà
    "sleep_restless": "http://localhost:3845/assets/6a800301730ec9816ded760306228a8adc25e7a0.svg",  # Agitato
    "sleep_insomnia": "http://localhost:3845/assets/eca52be8156d4345995ca6daab59e7054e51892d.svg",  # Insonnia
}

def create_contents_json():
    """Create Contents.json for template rendering"""
    return {
        "images": [
            {
                "filename": None,  # Will be set per icon
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "template-rendering-intent": "template"
        }
    }

def download_icon(name, url):
    """Download a single icon from Figma"""
    imageset_path = os.path.join(ASSETS_PATH, f"{name}.imageset")
    svg_path = os.path.join(imageset_path, f"{name}.svg")
    contents_path = os.path.join(imageset_path, "Contents.json")
    
    # Create directory if it doesn't exist
    os.makedirs(imageset_path, exist_ok=True)
    
    try:
        # Download SVG
        print(f"Downloading {name}...")
        urllib.request.urlretrieve(url, svg_path)
        
        # Create Contents.json
        contents = create_contents_json()
        contents["images"][0]["filename"] = f"{name}.svg"
        
        with open(contents_path, 'w') as f:
            json.dump(contents, f, indent=2)
        
        print(f"  ✓ {name} saved")
        return True
    except Exception as e:
        print(f"  ✗ Error downloading {name}: {e}")
        return False

def main():
    print("Downloading Figma icons...")
    print(f"Target: {ASSETS_PATH}")
    print()
    
    success = 0
    failed = 0
    
    for name, url in FIGMA_ICONS.items():
        if download_icon(name, url):
            success += 1
        else:
            failed += 1
    
    print()
    print(f"Done! Success: {success}, Failed: {failed}")

if __name__ == "__main__":
    main()
