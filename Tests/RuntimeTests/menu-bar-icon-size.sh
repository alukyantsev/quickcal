#!/usr/bin/env bash
set -euo pipefail

PROCESS_NAME="${1:-QuickCal}"
REFERENCE_OPTICAL_HEIGHT_POINTS="${REFERENCE_OPTICAL_HEIGHT_POINTS:-17}"
MINIMUM_REFERENCE_RATIO="${MINIMUM_REFERENCE_RATIO:-0.95}"

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-menu-icon.XXXXXX")"
SCREENSHOT="${TEMP_DIRECTORY}/icon.png"
RAW_IMAGE="${TEMP_DIRECTORY}/icon.rgb"

close_popover() {
    osascript >/dev/null <<APPLESCRIPT
tell application "System Events"
    tell process "${PROCESS_NAME}"
        repeat with targetBar in menu bars
            repeat with targetItem in menu bar items of targetBar
                try
                    set itemName to name of targetItem
                    set itemDescription to description of targetItem
                    if itemName is "${PROCESS_NAME}" or itemDescription is "${PROCESS_NAME}" then
                        if exists pop over 1 of targetBar then
                            click targetItem
                            return
                        end if
                    end if
                end try
            end repeat
        end repeat
    end tell
end tell
APPLESCRIPT
}

cleanup() {
    close_popover || true
    rm -rf "${TEMP_DIRECTORY}"
}
trap cleanup EXIT

BOUNDS="$(
    osascript <<APPLESCRIPT
tell application "System Events"
    tell process "${PROCESS_NAME}"
        repeat with targetBar in menu bars
            repeat with targetItem in menu bar items of targetBar
                try
                    set itemName to name of targetItem
                    set itemDescription to description of targetItem
                    if itemName is "${PROCESS_NAME}" or itemDescription is "${PROCESS_NAME}" then
                        set itemPosition to position of targetItem
                        set itemSize to size of targetItem
                        if (item 1 of itemSize) > 0 and (item 2 of itemSize) > 0 then
                            if exists pop over 1 of targetBar then
                                click targetItem
                                delay 0.1
                            end if
                            click targetItem
                            delay 0.2
                            return (item 1 of itemPosition as text) & "," & ¬
                                (item 2 of itemPosition as text) & "," & ¬
                                (item 1 of itemSize as text) & "," & ¬
                                (item 2 of itemSize as text)
                        end if
                    end if
                end try
            end repeat
        end repeat
    end tell
end tell
error "menu bar item not found for ${PROCESS_NAME}"
APPLESCRIPT
)"

IFS=, read -r ITEM_X ITEM_Y ITEM_WIDTH ITEM_HEIGHT <<<"${BOUNDS}"

screencapture \
    -x \
    -R"${ITEM_X},${ITEM_Y},${ITEM_WIDTH},${ITEM_HEIGHT}" \
    "${SCREENSHOT}"
ffmpeg \
    -v error \
    -y \
    -i "${SCREENSHOT}" \
    -f rawvideo \
    -pix_fmt rgb24 \
    "${RAW_IMAGE}"

IMAGE_WIDTH="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=width \
        -of csv=p=0 \
        "${SCREENSHOT}"
)"
IMAGE_HEIGHT="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=height \
        -of csv=p=0 \
        "${SCREENSHOT}"
)"

python3 - \
    "${RAW_IMAGE}" \
    "${IMAGE_WIDTH}" \
    "${IMAGE_HEIGHT}" \
    "${ITEM_WIDTH}" \
    "${REFERENCE_OPTICAL_HEIGHT_POINTS}" \
    "${MINIMUM_REFERENCE_RATIO}" <<'PY'
import sys
from math import sqrt
from pathlib import Path
from statistics import median

raw_path = Path(sys.argv[1])
width = int(sys.argv[2])
height = int(sys.argv[3])
item_width_points = float(sys.argv[4])
reference_height_points = float(sys.argv[5])
minimum_reference_ratio = float(sys.argv[6])
pixels = raw_path.read_bytes()

if len(pixels) != width * height * 3:
    raise SystemExit("error: unexpected RGB byte count")

def pixel_at(x, y):
    offset = (y * width + x) * 3
    return tuple(pixels[offset:offset + 3])

sample_y_start = max(0, height // 2 - 4)
sample_y_end = min(height, height // 2 + 5)
sample_x_ranges = (
    range(4, min(14, width // 4)),
    range(max(width * 3 // 4, width - 14), max(width - 4, 1)),
)
background_samples = [
    pixel_at(x, y)
    for y in range(sample_y_start, sample_y_end)
    for sample_x_range in sample_x_ranges
    for x in sample_x_range
]
if not background_samples:
    raise SystemExit("error: no local background samples")

background = tuple(
    median(sample[channel] for sample in background_samples)
    for channel in range(3)
)

mask = set()
for y in range(height):
    for x in range(width):
        red, green, blue = pixel_at(x, y)
        color_distance = sqrt(
            (red - background[0]) ** 2
            + (green - background[1]) ** 2
            + (blue - background[2]) ** 2
        )
        pixel_luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        background_luminance = (
            0.2126 * background[0]
            + 0.7152 * background[1]
            + 0.0722 * background[2]
        )
        if (
            color_distance >= 50
            and abs(pixel_luminance - background_luminance) >= 30
        ):
            mask.add((x, y))

components = []
while mask:
    seed = mask.pop()
    component = {seed}
    pending = [seed]
    while pending:
        x, y = pending.pop()
        for neighbor_y in range(y - 1, y + 2):
            for neighbor_x in range(x - 1, x + 2):
                neighbor = (neighbor_x, neighbor_y)
                if neighbor in mask:
                    mask.remove(neighbor)
                    component.add(neighbor)
                    pending.append(neighbor)
    if len(component) >= 20:
        xs = [point[0] for point in component]
        ys = [point[1] for point in component]
        component_width = max(xs) - min(xs) + 1
        component_height = max(ys) - min(ys) + 1
        if component_width < width * 0.75 and component_height < height * 0.9:
            components.append(component)

if not components:
    raise SystemExit("error: no contrasting icon component detected")

center_x = (width - 1) / 2
center_y = (height - 1) / 2

def component_distance(component):
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    component_center_x = (min(xs) + max(xs)) / 2
    component_center_y = (min(ys) + max(ys)) / 2
    return (component_center_x - center_x) ** 2 + (component_center_y - center_y) ** 2

icon = min(components, key=component_distance)
xs = [point[0] for point in icon]
ys = [point[1] for point in icon]
optical_width_pixels = max(xs) - min(xs) + 1
optical_height_pixels = max(ys) - min(ys) + 1
display_scale = width / item_width_points
optical_height_points = optical_height_pixels / display_scale
reference_ratio = optical_height_points / reference_height_points

print(
    "menu icon optical bounds: "
    f"{optical_width_pixels}x{optical_height_pixels}px, "
    f"height={optical_height_points:.2f}pt, "
    f"ChatGPT-reference={reference_height_points:.2f}pt, "
    f"ratio={reference_ratio:.3f}"
)

if reference_ratio < minimum_reference_ratio:
    raise SystemExit(
        "error: menu icon is not optically comparable to the reference: "
        f"{reference_ratio:.3f} < {minimum_reference_ratio:.3f}"
    )
PY
