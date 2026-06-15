#!/usr/bin/env python3
"""Flatten a GDS into a compact layers JSON for the in-app 3D viewer.

Emits { bbox:[x0,y0,x1,y1], unit:"um", layers:[{name,layer,datatype,z,height,
color,polygons:[[[x,y],...],...]}] } with coordinates in microns. gdstk does the
hierarchy flattening so the browser viewer is a pure renderer (no GDS parsing).

Usage:  gds_to_json.py <in.gds> <out.json> [max_polys_per_layer=4000]
"""
import sys
import json
import collections
import gdstk

# Layer -> (display name, z-order index, slab thickness, hex color). Z-order
# roughly follows the SKY130 fabrication stack (substrate up to top metal).
STACK = {
    (64, 20): ("nwell", 0, 0.3, "#3b3b6b"),
    (65, 20): ("diff", 1, 0.3, "#7a5230"),
    (66, 20): ("poly", 2, 0.3, "#d23b3b"),
    (66, 44): ("licon1", 3, 0.3, "#888888"),
    (67, 20): ("li1", 4, 0.4, "#c0922a"),
    (67, 44): ("mcon", 5, 0.3, "#aaaaaa"),
    (68, 20): ("met1", 6, 0.5, "#2a7ac0"),
    (68, 44): ("via", 7, 0.3, "#cccccc"),
    (69, 20): ("met2", 8, 0.5, "#5ab0e0"),
    (69, 44): ("via2", 9, 0.3, "#dddddd"),
    (70, 20): ("met3", 10, 0.6, "#7ec850"),
    (70, 44): ("via3", 11, 0.3, "#eeeeee"),
    (71, 20): ("met4", 12, 0.7, "#e0a030"),
    (76, 20): ("pad", 14, 0.8, "#e8d44a"),
    # Custom / analog layers
    (1, 0): ("bottom electrode", 0, 0.4, "#2a7ac0"),
    (2, 0): ("resistive", 1, 0.4, "#d23b3b"),
    (3, 0): ("top electrode", 2, 0.4, "#e0a030"),
    (4, 0): ("pad opening", 3, 0.5, "#e8d44a"),
    (5, 0): ("resistor film", 1, 0.4, "#7ec850"),
    (6, 0): ("poly", 2, 0.3, "#d23b3b"),
    (7, 0): ("active", 1, 0.3, "#7a5230"),
    (8, 0): ("contact", 3, 0.3, "#aaaaaa"),
    (9, 0): ("nwell", 0, 0.3, "#3b3b6b"),
}


def main():
    gds_in, out = sys.argv[1], sys.argv[2]
    cap = int(sys.argv[3]) if len(sys.argv) > 3 else 4000

    lib = gdstk.read_gds(gds_in)
    cell = max(lib.top_level(), key=lambda c: len(c.get_polygons()))
    bb = cell.bounding_box()
    (x0, y0), (x1, y1) = bb

    by_layer = collections.defaultdict(list)
    for p in cell.get_polygons():
        by_layer[(p.layer, p.datatype)].append([[round(x, 3), round(y, 3)] for x, y in p.points])

    layers = []
    for (layer, dt), polys in by_layer.items():
        name, z, height, color = STACK.get((layer, dt), (f"L{layer}D{dt}", 13, 0.4, "#9aa0a6"))
        dropped = max(0, len(polys) - cap)
        layers.append({
            "name": name, "layer": layer, "datatype": dt,
            "z": z, "height": height, "color": color,
            "count": len(polys), "dropped": dropped,
            "polygons": polys[:cap],
        })
    layers.sort(key=lambda l: l["z"])

    out_obj = {
        "bbox": [round(x0, 3), round(y0, 3), round(x1, 3), round(y1, 3)],
        "unit": "um",
        "topCell": cell.name,
        "layers": layers,
    }
    json.dump(out_obj, open(out, "w"))
    print(f"wrote {out}: {len(layers)} layers, {sum(l['count'] for l in layers)} polys "
          f"({sum(l['dropped'] for l in layers)} capped)")


if __name__ == "__main__":
    main()
