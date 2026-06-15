#!/usr/bin/env python3
"""Stamp large square bond pads onto an OpenLane macro GDS.

OpenLane's FP_PIN_ORDER_CFG places thin metal *pins* on the die edge — too
narrow to wire-bond. This adds a real square bond pad per signal on the side
the user chose (read from pin_order.cfg), big enough for manual wire bonding,
plus a short stub toward the core and a text label. One pad per signal/bus
entry (standard practice — a bus shares one bond pad group here).

Usage:  stamp_pads.py <in.gds> <out.gds> <pin_order.cfg> [pad_um=70]
"""
import sys
import gdstk

L_TOPMET = 71   # met4 (high metal) — pad metal
L_TOPDT = 20
L_PADOPEN = 76  # pad / passivation opening (sky130 "pad")
L_PADDT = 20

SECTIONS = {"#N": "top", "#E": "right", "#S": "bottom", "#W": "left"}


def parse_pin_cfg(path):
    """Return {side: [display_name, ...]} from a pin_order.cfg."""
    sides = {"top": [], "right": [], "bottom": [], "left": []}
    cur = None
    for raw in open(path):
        l = raw.strip()
        if not l:
            continue
        if l in SECTIONS:
            cur = SECTIONS[l]
        elif cur:
            # Derive a readable name from the regex (strip ^$ \ [ .* ])
            name = l.replace("^", "").replace("$", "").replace("\\", "")
            name = name.replace("[.*]", "").replace(".*", "").replace("[", "").replace("]", "")
            sides[cur].append(name or l)
    return sides


def main():
    gds_in, gds_out, cfg = sys.argv[1], sys.argv[2], sys.argv[3]
    pad = float(sys.argv[4]) if len(sys.argv) > 4 else 70.0

    lib = gdstk.read_gds(gds_in)
    cell = lib.top_level()[0]
    bb = cell.bounding_box()
    (x0, y0), (x1, y1) = bb
    W, H = x1 - x0, y1 - y0
    sides = parse_pin_cfg(cfg)

    stub = pad * 0.4

    def place_side(names, side):
        n = len(names)
        if n == 0:
            return
        for i, name in enumerate(names):
            frac = (i + 1) / (n + 1)
            if side in ("top", "bottom"):
                cx = x0 + frac * W
                if side == "top":
                    py1 = y1 - 2; py0 = py1 - pad; sy0, sy1 = py0, py0  # stub down
                    cell.add(gdstk.rectangle((cx - 4, py0 - stub), (cx + 4, py0), layer=L_TOPMET, datatype=L_TOPDT))
                else:
                    py0 = y0 + 2; py1 = py0 + pad
                    cell.add(gdstk.rectangle((cx - 4, py1), (cx + 4, py1 + stub), layer=L_TOPMET, datatype=L_TOPDT))
                px0, px1 = cx - pad / 2, cx + pad / 2
            else:
                cy = y0 + frac * H
                if side == "left":
                    px0 = x0 + 2; px1 = px0 + pad
                    cell.add(gdstk.rectangle((px1, cy - 4), (px1 + stub, cy + 4), layer=L_TOPMET, datatype=L_TOPDT))
                else:
                    px1 = x1 - 2; px0 = px1 - pad
                    cell.add(gdstk.rectangle((px0 - stub, cy - 4), (px0, cy + 4), layer=L_TOPMET, datatype=L_TOPDT))
                py0, py1 = cy - pad / 2, cy + pad / 2
            # Square pad: top metal + pad opening + label.
            cell.add(gdstk.rectangle((px0, py0), (px1, py1), layer=L_TOPMET, datatype=L_TOPDT))
            cell.add(gdstk.rectangle((px0 + 6, py0 + 6), (px1 - 6, py1 - 6), layer=L_PADOPEN, datatype=L_PADDT))
            cell.add(gdstk.Label(name, ((px0 + px1) / 2, (py0 + py1) / 2), layer=L_PADOPEN, texttype=L_PADDT))

    for side, names in sides.items():
        place_side(names, side)

    lib.write_gds(gds_out)
    total = sum(len(v) for v in sides.values())
    print(f"stamped {total} bond pads ({pad:.0f}um) onto {gds_out}")


if __name__ == "__main__":
    main()
