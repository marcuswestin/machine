#!/usr/bin/env bash
# Build Claude Notify.app (UserNotifications helper with a Claude+bell icon).
# macOS always draws the posting app's icon on banners; osascript cannot override it.
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
out="$root/Claude Notify.app"
base_png="$root/claude-base.png"
icon_png="$root/claude.png"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Composite a gold notification bell onto the Claude mark so this helper is
# visually distinct from Claude.app in Notification Center.
swift -e '
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let baseURL = root.appendingPathComponent("claude-base.png")
let outURL = root.appendingPathComponent("claude.png")
guard let base = NSImage(contentsOf: baseURL),
      let tiff = base.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { fatalError("load base") }
let w = rep.pixelsWide
let h = rep.pixelsHigh
let out = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
out.size = NSSize(width: w, height: h)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)!
base.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .copy, fraction: 1)
let badge = CGFloat(w) * 0.38
let margin = CGFloat(w) * 0.04
let br = NSRect(x: CGFloat(w) - badge - margin, y: margin, width: badge, height: badge)
let disc = br.insetBy(dx: badge * 0.06, dy: badge * 0.06)
NSColor(calibratedWhite: 0.08, alpha: 0.55).setFill()
NSBezierPath(ovalIn: disc).fill()
NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
let discStroke = NSBezierPath(ovalIn: disc)
discStroke.lineWidth = max(2, badge * 0.03)
discStroke.stroke()
let gold = NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.22, alpha: 1)
let goldDark = NSColor(calibratedRed: 0.72, green: 0.52, blue: 0.08, alpha: 1)
let goldLight = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.55, alpha: 1)
let cx = br.midX
let cy = br.midY + badge * 0.02
let bellW = badge * 0.42
let bellH = badge * 0.40
let top = cy + bellH * 0.55
let bottom = cy - bellH * 0.45
let body = NSBezierPath()
body.move(to: NSPoint(x: cx - bellW * 0.55, y: bottom + bellH * 0.25))
body.curve(to: NSPoint(x: cx, y: top),
           controlPoint1: NSPoint(x: cx - bellW * 0.55, y: top - bellH * 0.05),
           controlPoint2: NSPoint(x: cx - bellW * 0.15, y: top))
body.curve(to: NSPoint(x: cx + bellW * 0.55, y: bottom + bellH * 0.25),
           controlPoint1: NSPoint(x: cx + bellW * 0.15, y: top),
           controlPoint2: NSPoint(x: cx + bellW * 0.55, y: top - bellH * 0.05))
body.curve(to: NSPoint(x: cx + bellW * 0.72, y: bottom),
           controlPoint1: NSPoint(x: cx + bellW * 0.62, y: bottom + bellH * 0.12),
           controlPoint2: NSPoint(x: cx + bellW * 0.72, y: bottom + bellH * 0.04))
body.line(to: NSPoint(x: cx - bellW * 0.72, y: bottom))
body.curve(to: NSPoint(x: cx - bellW * 0.55, y: bottom + bellH * 0.25),
           controlPoint1: NSPoint(x: cx - bellW * 0.72, y: bottom + bellH * 0.04),
           controlPoint2: NSPoint(x: cx - bellW * 0.62, y: bottom + bellH * 0.12))
body.close()
gold.setFill(); body.fill()
let hi = NSBezierPath()
hi.move(to: NSPoint(x: cx - bellW * 0.35, y: bottom + bellH * 0.35))
hi.curve(to: NSPoint(x: cx - bellW * 0.12, y: top - bellH * 0.08),
         controlPoint1: NSPoint(x: cx - bellW * 0.38, y: top - bellH * 0.15),
         controlPoint2: NSPoint(x: cx - bellW * 0.2, y: top - bellH * 0.05))
hi.lineWidth = max(2, badge * 0.045)
goldLight.withAlphaComponent(0.75).setStroke(); hi.stroke()
let yokeR = badge * 0.055
goldDark.setFill()
NSBezierPath(ovalIn: NSRect(x: cx - yokeR, y: top - yokeR * 0.2, width: yokeR * 2, height: yokeR * 2)).fill()
let clapR = badge * 0.07
let clap = NSBezierPath(ovalIn: NSRect(x: cx - clapR, y: bottom - clapR * 1.6, width: clapR * 2, height: clapR * 2))
gold.setFill(); clap.fill()
goldDark.setStroke(); clap.lineWidth = max(1, badge * 0.02); clap.stroke()
NSGraphicsContext.restoreGraphicsState()
guard let png = out.representation(using: .png, properties: [:]) else { fatalError("png") }
try png.write(to: outURL)
' "$root"

mkdir -p "$workdir/AppIcon.iconset"
for sz in 16 32 128 256 512; do
  sips -z "$sz" "$sz" "$icon_png" --out "$workdir/AppIcon.iconset/icon_${sz}x${sz}.png" >/dev/null
  if [ "$sz" -lt 512 ]; then
    sips -z $((sz * 2)) $((sz * 2)) "$icon_png" --out "$workdir/AppIcon.iconset/icon_${sz}x${sz}@2x.png" >/dev/null
  fi
done
iconutil -c icns "$workdir/AppIcon.iconset" -o "$workdir/AppIcon.icns"

swiftc -O -whole-module-optimization \
  -framework AppKit -framework UserNotifications \
  -o "$workdir/claude-notify" \
  "$root/main.swift"

rm -rf "$out"
mkdir -p "$out/Contents/MacOS" "$out/Contents/Resources"
cp "$root/Info.plist" "$out/Contents/Info.plist"
cp "$workdir/claude-notify" "$out/Contents/MacOS/claude-notify"
cp "$workdir/AppIcon.icns" "$out/Contents/Resources/AppIcon.icns"
codesign --force --deep -s - "$out" >/dev/null

printf 'Built %s\n' "$out"
