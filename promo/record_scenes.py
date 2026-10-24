"""Choreographed promo clip recorder for Opal.
Records 60fps clips demonstrating every key capability of the shell.
"""
import json, os, pathlib, subprocess, sys, time
from session import Attached, Session, CLIPS

def reset_clean(s):
    s.ipc('switcherCancel')
    s.ipc('close')
    s.ipc('powerMenuClose')
    time.sleep(0.5)

def record_desktop_flow(s):
    print("Recording scene 1: Desktop Flow & Launch...")
    reset_clean(s)
    s.record('scene1-desktop')
    time.sleep(0.5)
    
    # Cursor glides from center to launcher icon at bottom left
    s.glide(30, 1055, seconds=0.7)
    time.sleep(0.2)
    s.click(30, 1055)
    time.sleep(0.8)
    
    # Type to search
    s.type('photos', cps=12)
    time.sleep(0.8)
    
    # Press Return to launch
    s.tap('Return')
    time.sleep(1.2)
    
    s.stop_recording()
    print("Scene 1 recorded.")

def record_multitask(s):
    print("Recording scene 2: Multitasking & App Switcher...")
    reset_clean(s)
    s.record('scene2-switcher')
    time.sleep(0.5)
    
    # Open app switcher strip
    s.ipc('switcherOpen')
    time.sleep(1.2)
    s.tap('Right')
    time.sleep(0.6)
    s.tap('Right')
    time.sleep(0.6)
    # Toggle switcher closed
    s.ipc('switcherOpen')
    time.sleep(0.8)
    
    # Workspace jump OSD
    s.lua('hl.dispatch(hl.dsp.focus({workspace="2"}))')
    time.sleep(1.0)
    s.lua('hl.dispatch(hl.dsp.focus({workspace="1"}))')
    time.sleep(0.8)
    
    s.stop_recording()
    reset_clean(s)
    print("Scene 2 recorded.")

def record_customization(s):
    print("Recording scene 3: Wallpaper & Style / Material 3...")
    reset_clean(s)
    s.record('scene3-style')
    time.sleep(0.5)
    
    # Open Wallpaper & Style
    s.ipc('appearance')
    time.sleep(1.5)
    
    # Glide to theme toggles / color swatches
    s.glide(440, 580, seconds=0.6)
    time.sleep(0.4)
    s.click(440, 580)
    time.sleep(0.8)
    
    # Toggle Dark / Light theme
    s.glide(760, 720, seconds=0.6)
    time.sleep(0.3)
    s.click(760, 720) # Toggle to Light
    time.sleep(1.4)
    
    s.click(760, 720) # Toggle back to Dark
    time.sleep(1.0)
    
    s.ipc('close')
    time.sleep(0.8)
    s.stop_recording()
    reset_clean(s)
    print("Scene 3 recorded.")

def record_panels(s):
    print("Recording scene 4: Quick Settings, Media & Assistant...")
    reset_clean(s)
    s.record('scene4-panels')
    time.sleep(0.5)
    
    # Open Quick Settings & Notifications
    s.ipc('notifications')
    time.sleep(2.0)
    s.ipc('close')
    time.sleep(0.8)
    
    # Open Claude Assistant
    s.ipc('assistant')
    time.sleep(2.0)
    s.ipc('close')
    time.sleep(0.8)
    
    s.stop_recording()
    reset_clean(s)
    print("Scene 4 recorded.")

if __name__ == '__main__':
    desk = Attached('desk')
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            if arg == '1': record_desktop_flow(desk)
            elif arg == '2': record_multitask(desk)
            elif arg == '3': record_customization(desk)
            elif arg == '4': record_panels(desk)
    else:
        record_multitask(desk)
        record_customization(desk)
        record_panels(desk)
    print("Scenes updated successfully!")
