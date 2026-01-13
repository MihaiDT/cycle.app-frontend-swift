#!/usr/bin/env python3
"""Generate simple SVG icons for all symptoms with consistent design."""

import os

ASSETS_PATH = "../CycleApp/Resources/Assets.xcassets/Symptoms"
COLOR = "#5C4A3B"

# Icon definitions: name -> SVG paths
ICONS = {
    # MOOD icons - emoji style faces
    "mood_calm": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 10C8.5 9.5 9 9.5 9.5 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M14.5 10C15 9.5 15.5 9.5 16 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 14.5C9.5 16.5 14.5 16.5 16 14.5" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_happy": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M7 14C8.5 17 15.5 17 17 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_sensitive": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M9 15C10.5 16 13.5 16 15 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M16 11L17 13" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>''',
    
    "mood_sad": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M8 16C9.5 14 14.5 14 16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_apathetic": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<line x1="8" y1="15" x2="16" y2="15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_tired": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 10L11 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M13 10L17 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<ellipse cx="12" cy="15" rx="2" ry="2.5" stroke="{COLOR}" stroke-width="1.5" fill="none"/>''',
    
    "mood_angry": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 8L10 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 8L14 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<circle cx="9" cy="11" r="1" fill="{COLOR}"/>
<circle cx="15" cy="11" r="1" fill="{COLOR}"/>
<path d="M8 16C9.5 14 14.5 14 16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_selfcritical": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M9 16L15 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_lively": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 9L9 11L11 9" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13 9L15 11L17 9" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M7 14C8.5 17 15.5 17 17 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_motivated": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M7 14C8.5 17 15.5 17 17 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 4L12 2" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 5L18 3" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M7 5L6 3" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_anxious": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="15" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="0.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="0.5" fill="{COLOR}"/>
<ellipse cx="12" cy="16" rx="2" ry="1.5" stroke="{COLOR}" stroke-width="1.5" fill="none"/>''',
    
    "mood_confident": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M8 14C9 16 11 17 12 17C13 17 15 16 16 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M6 7L9 9" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M18 7L15 9" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_irritable": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 9L10 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 9L14 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<circle cx="9" cy="11" r="1" fill="{COLOR}"/>
<circle cx="15" cy="11" r="1" fill="{COLOR}"/>
<path d="M9 16L15 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "mood_emotional": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M8 15C9.5 17 14.5 17 16 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M7 11L7 14" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>
<path d="M17 11L17 14" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>''',
    
    "mood_swings": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M8 14C9 16 10 16 12 15C14 14 15 14 16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    # ENERGY icons
    "energy_low": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 16L12 12L16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M12 12L12 8" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "energy_normal": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 12L16 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 8L12 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "energy_high": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6L12 18" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 10L12 6L16 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M8 14L12 10L16 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    # STRESS icons
    "stress_zero": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 12C8 10 10 8 12 8C14 8 16 10 16 12C16 14 14 16 12 16C10 16 8 14 8 12" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="12" cy="12" r="2" fill="{COLOR}"/>''',
    
    "stress_manageable": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6L12 12L16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "stress_intense": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6L12 13" stroke="{COLOR}" stroke-width="2" stroke-linecap="round"/>
<circle cx="12" cy="17" r="1.5" fill="{COLOR}"/>''',
    
    # SLEEP icons
    "sleep_peaceful": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 10L10 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M14 10L17 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 15C9.5 16.5 14.5 16.5 16 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 4L19 6L17 6L19 8" stroke="{COLOR}" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "sleep_difficulty": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<line x1="8" y1="15" x2="16" y2="15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 3L19 5L17 5L19 7" stroke="{COLOR}" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M5 5L7 7L5 7L7 9" stroke="{COLOR}" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "sleep_restless": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="15" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M9 16L15 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "sleep_insomnia": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="15" cy="10" r="2" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="0.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="0.5" fill="{COLOR}"/>
<path d="M8 16C9.5 14 14.5 14 16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    # SKIN icons
    "skin_normal": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="12" cy="12" r="4" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 4L12 8" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 16L12 20" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M4 12L8 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M16 12L20 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "skin_dry": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 8L9 10L10 8L11 10L12 8L13 10L14 8L15 10L16 8" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M8 12L9 14L10 12L11 14L12 12L13 14L14 12L15 14L16 12" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M8 16L9 18L10 16L11 18L12 16L13 18L14 16L15 18L16 16" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "skin_oily": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<ellipse cx="9" cy="10" rx="2" ry="2.5" fill="{COLOR}" opacity="0.5"/>
<ellipse cx="15" cy="10" rx="2" ry="2.5" fill="{COLOR}" opacity="0.5"/>
<ellipse cx="12" cy="15" rx="2.5" ry="2" fill="{COLOR}" opacity="0.5"/>''',
    
    "skin_acne": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="8" cy="9" r="1.5" fill="{COLOR}"/>
<circle cx="14" cy="8" r="1" fill="{COLOR}"/>
<circle cx="16" cy="12" r="1.5" fill="{COLOR}"/>
<circle cx="10" cy="14" r="1" fill="{COLOR}"/>
<circle cx="14" cy="16" r="1.5" fill="{COLOR}"/>''',
    
    "skin_itchy": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M7 9L9 11L7 13" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M11 7L13 9L11 11L13 13L11 15L13 17" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M17 9L15 11L17 13" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    # HAIR icons
    "hair_normal": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M6 10C6 6 9 4 12 4C15 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M9 12C9 12 10 10 12 10C14 10 15 12 15 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "hair_shiny": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M6 10C6 6 9 4 12 4C15 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 7L10 9" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M14 6L15 8" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "hair_oily": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M6 10C6 6 9 4 12 4C15 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<ellipse cx="9" cy="8" rx="1.5" ry="2" fill="{COLOR}" opacity="0.5"/>
<ellipse cx="15" cy="8" rx="1.5" ry="2" fill="{COLOR}" opacity="0.5"/>''',
    
    "hair_dry": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M6 10C6 6 9 4 12 4C15 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 6L9 8L8 10" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>
<path d="M11 5L12 7L11 9" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>
<path d="M15 6L16 8L15 10" stroke="{COLOR}" stroke-width="1" stroke-linecap="round"/>''',
    
    "hair_sensitive": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M6 10C6 6 9 4 12 4C15 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<circle cx="9" cy="7" r="1" fill="{COLOR}"/>
<circle cx="12" cy="6" r="1" fill="{COLOR}"/>
<circle cx="15" cy="7" r="1" fill="{COLOR}"/>''',
    
    "hair_loss": f'''<circle cx="12" cy="14" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 10C8 7 10 5 12 5C14 5 16 7 16 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M5 4L7 8" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M19 4L17 8" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M4 8L6 10" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M20 8L18 10" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>''',
    
    # PHYSICAL symptoms
    "physical_cramps": f'''<ellipse cx="12" cy="14" rx="7" ry="5" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 13L9 15L10 13L11 15L12 13L13 15L14 13L15 15L16 13" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M10 6L12 4L14 6" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "physical_headache": f'''<circle cx="12" cy="12" r="8" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 9L10 11M16 9L14 11" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M9 15L12 13L15 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M4 6L6 8" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M20 6L18 8" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M12 2L12 4" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>''',
    
    "physical_backpain": f'''<path d="M12 4C12 4 8 7 8 12C8 17 12 20 12 20" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 4C12 4 16 7 16 12C16 17 12 20 12 20" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M5 10L8 12L5 14" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M19 10L16 12L19 14" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "physical_bloating": f'''<ellipse cx="12" cy="13" rx="8" ry="7" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 4L12 3L16 4" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9 11L15 11" stroke="{COLOR}" stroke-width="1" stroke-linecap="round" stroke-dasharray="2 2"/>
<path d="M8 14L16 14" stroke="{COLOR}" stroke-width="1" stroke-linecap="round" stroke-dasharray="2 2"/>''',
    
    "physical_breast": f'''<path d="M6 10C6 6 8 4 12 4C16 4 18 6 18 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M6 10C4 14 6 18 10 19" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M18 10C20 14 18 18 14 19" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M10 19C11 20 13 20 14 19" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<circle cx="9" cy="14" r="1" fill="{COLOR}"/>
<circle cx="15" cy="14" r="1" fill="{COLOR}"/>''',
    
    "physical_nausea": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="9" cy="10" r="1.5" fill="{COLOR}"/>
<circle cx="15" cy="10" r="1.5" fill="{COLOR}"/>
<path d="M8 15C8 15 9 17 12 17C15 17 16 15 16 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M17 14C19 14 20 13 20 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "physical_acne": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="8" cy="9" r="2" fill="{COLOR}"/>
<circle cx="15" cy="8" r="1.5" fill="{COLOR}"/>
<circle cx="16" cy="13" r="2" fill="{COLOR}"/>
<circle cx="9" cy="15" r="1.5" fill="{COLOR}"/>
<circle cx="13" cy="16" r="1" fill="{COLOR}"/>''',
    
    "physical_dizziness": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6C8 6 6 9 6 12C6 15 8 18 12 18C16 18 18 15 18 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-dasharray="3 3"/>
<circle cx="12" cy="12" r="2" fill="{COLOR}"/>
<path d="M12 6L14 4" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "physical_hotflash": f'''<path d="M12 3L14 8L12 7L14 12L12 11L14 16L10 10L12 11L10 6L12 7L10 3L12 3Z" stroke="{COLOR}" stroke-width="1.2" fill="none" stroke-linejoin="round"/>
<path d="M6 18L8 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M18 18L16 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 21L12 18" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "physical_joint": f'''<circle cx="8" cy="8" r="3" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<circle cx="16" cy="16" r="3" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M10 10L14 14" stroke="{COLOR}" stroke-width="2" stroke-linecap="round"/>
<path d="M6 12L4 14" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M12 6L14 4" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>
<path d="M18 12L20 10" stroke="{COLOR}" stroke-width="1.2" stroke-linecap="round"/>''',
    
    # DIGESTIVE symptoms
    "digestive_constipation": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6L12 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 10L12 14L16 10" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M8 16L16 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "digestive_diarrhea": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M12 6L12 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M8 8L12 12L16 8" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9 15L12 18L15 15" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
    
    "digestive_appetite": f'''<circle cx="12" cy="12" r="10" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M8 8L8 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M12 6L12 18" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>
<path d="M16 10L16 14" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
    
    "digestive_cravings": f'''<path d="M12 4C12 4 6 8 6 14C6 18 9 20 12 20C15 20 18 18 18 14C18 8 12 4 12 4Z" stroke="{COLOR}" stroke-width="1.5" fill="none"/>
<path d="M10 12L12 10L14 12" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M12 10L12 16" stroke="{COLOR}" stroke-width="1.5" stroke-linecap="round"/>''',
}

CONTENTS_JSON = '''{
  "images" : [{"filename" : "NAME.svg", "idiom" : "universal"}],
  "info" : {"author" : "xcode", "version" : 1},
  "properties" : {"preserves-vector-representation" : true, "template-rendering-intent" : "template"}
}'''

def create_svg(name, paths):
    svg = f'''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
{paths}
</svg>'''
    return svg

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_path = os.path.join(script_dir, ASSETS_PATH)
    
    for name, paths in ICONS.items():
        imageset_dir = os.path.join(assets_path, f"{name}.imageset")
        os.makedirs(imageset_dir, exist_ok=True)
        
        # Write SVG
        svg_path = os.path.join(imageset_dir, f"{name}.svg")
        with open(svg_path, 'w') as f:
            f.write(create_svg(name, paths))
        
        # Write Contents.json
        contents_path = os.path.join(imageset_dir, "Contents.json")
        with open(contents_path, 'w') as f:
            f.write(CONTENTS_JSON.replace("NAME", name))
        
        print(f"Created {name}")
    
    print(f"\nTotal: {len(ICONS)} icons created")

if __name__ == "__main__":
    main()
