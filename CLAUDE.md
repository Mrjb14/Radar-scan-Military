# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Garmin Connect IQ watchface application written in Monkey C. The watchface represents a **military radar scan display** with a rotating sweep line that completes one full rotation per minute. Health metrics (heart rate, steps, battery) appear as animated "blips" on the radar, and time/date are displayed in the center.

## Build & Development

This project uses the Garmin Connect IQ SDK with VS Code extension. Common commands:

- **Build**: Use VS Code command palette → "Monkey C: Build Current Project" (Ctrl+Shift+P)
- **Run in Simulator**: "Monkey C: Run" or F5
- **Export for device**: "Monkey C: Export Project"

The build system uses `monkey.jungle` for project configuration and `manifest.xml` for app metadata.

## Architecture

- **Entry point**: `NewWatch1App.mc` - Main application class extending `Application.AppBase`
- **View**: `NewWatch1View.mc` - The watchface rendering logic (`WatchFace` class)
  - Uses 1Hz refresh rate with optimized partial redraws
  - Static elements drawn once, dynamic elements (scan line, time, blips) redrawn each update
- **Background**: `NewWatch1Background.mc` - Background drawable for settings-based colors

## Key Patterns

- All rendering uses Toybox.Graphics drawing primitives
- Dimensions scaled relative to screen size (`scale = screenWidth / 240.0`)
- Colors defined as hex constants (monochrome green theme: `0x00FF00`)
- Data sources: `ActivityMonitor` for steps/HR history, `Activity` for live HR, `System` for battery/clock

## Target Devices

Supports 100+ Garmin devices (Fenix, Forerunner, Venu, Instinct series, etc.) with minApiLevel 3.1.0.
