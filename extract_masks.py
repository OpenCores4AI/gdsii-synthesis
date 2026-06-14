#!/usr/bin/env python3
"""Extract per-layer photolithography masks from a GDSII file.

For every layer present in the layout this writes:
  * <name>.dark.png   — opaque geometry on clear field (positive-resist mask)
  * <name>.clear.png  — inverted polarity (negative-resist mask)
  * <name>.svg        — vector outline of that layer (for maskless aligners)
plus a combined colored preview and a manifest.json describing the stack.

Headless: uses gdstk (GDS parsing) + matplotlib Agg (rendering). No KLayout/Qt.

Usage:  python3 extract_masks.py <input.gds> <out_dir>
"""
import sys
import os
import json
import collections

import gdstk
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

# Common SKY130 (layer, datatype) -> human name. Unknown layers fall back to
# a generic L<layer>D<dt> label so nothing is silently dropped.
SKY130 = {
    (64, 20): "nwell", (64, 16): "nwell.pin",
    (65, 20): "diff", (65, 44): "tap",
    (66, 20): "poly", (66, 44): "licon1", (66, 15): "poly.label",
    (67, 20): "li1", (67, 44): "mcon", (67, 16): "li1.pin",
    (68, 20): "met1", (68, 44): "via", (68, 16): "met1.pin",
    (69, 20): "met2", (69, 44): "via2", (69, 16): "met2.pin",
    (70, 20): "met3", (70, 44): "via3",
    (71, 20): "met4", (71, 16): "met4.pin",
    (78, 44): "npc",
    (81, 4): "areaid.standardc",
    (93, 44): "nsdm",
    (94, 20): "psdm",
    (95, 20): "hvtp",
    (122, 16): "capm",
    (235, 4): "prBoundary",
    (236, 0): "outline",
}

# Rough fabrication order (bottom -> top) for sorting the manifest.
ORDER = ["nwell", "diff", "tap", "poly", "npc", "nsdm", "psdm", "hvtp",
         "licon1", "li1", "mcon", "met1", "via", "met2", "via2",
         "met3", "via3", "met4", "capm", "areaid.standardc", "prBoundary", "outline"]


def layer_name(layer, dt):
    return SKY130.get((layer, dt), f"L{layer}D{dt}")


def render_layer(polys, bbox, path, dark=True):
    (xmin, ymin), (xmax, ymax) = bbox
    w = max(xmax - xmin, 1e-3)
    h = max(ymax - ymin, 1e-3)
    aspect = h / w
    fig_w = 8.0
    fig = plt.figure(figsize=(fig_w, fig_w * aspect), dpi=200)
    ax = fig.add_axes([0, 0, 1, 1])
    bg = "white" if dark else "black"
    fg = "black" if dark else "white"
    ax.set_facecolor(bg)
    fig.patch.set_facecolor(bg)
    if polys:
        pc = PolyCollection(polys, facecolors=fg, edgecolors="none", antialiased=False)
        ax.add_collection(pc)
    ax.set_xlim(xmin, xmax)
    ax.set_ylim(ymin, ymax)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.savefig(path, facecolor=bg)
    plt.close(fig)


def render_svg(polys, bbox, path):
    (xmin, ymin), (xmax, ymax) = bbox
    w = max(xmax - xmin, 1e-3)
    h = max(ymax - ymin, 1e-3)
    fig = plt.figure(figsize=(8.0, 8.0 * (h / w)))
    ax = fig.add_axes([0, 0, 1, 1])
    if polys:
        pc = PolyCollection(polys, facecolors="black", edgecolors="none")
        ax.add_collection(pc)
    ax.set_xlim(xmin, xmax)
    ax.set_ylim(ymin, ymax)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.savefig(path, format="svg")
    plt.close(fig)


# SKY130 minimum drawn feature (poly / li1 width), in microns.
SKY130_MIN_FEATURE_UM = 0.13


def main():
    if len(sys.argv) < 3:
        print("usage: extract_masks.py <input.gds> <out_dir> [mode=real|micron] [min_feature_um=10]")
        sys.exit(1)
    gds_path, out_dir = sys.argv[1], sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else "real"
    target_min_um = float(sys.argv[4]) if len(sys.argv) > 4 else 10.0
    os.makedirs(out_dir, exist_ok=True)

    # Magnification. 'real' keeps true 130 nm geometry (NOT manually fabricable).
    # 'micron' uniformly scales the layout so the smallest feature reaches
    # target_min_um (~10 um), bringing it into manual photolithography range —
    # a topologically identical, functionally equivalent, physically larger
    # replica. Practical only for small designs.
    magnification = 1.0 if mode == "real" else (target_min_um / SKY130_MIN_FEATURE_UM)

    lib = gdstk.read_gds(gds_path)
    tops = lib.top_level()
    if not tops:
        print("ERROR: no top cell")
        sys.exit(1)
    cell = max(tops, key=lambda c: len(c.get_polygons()))

    # Group flattened polygons by (layer, datatype).
    by_layer = collections.defaultdict(list)
    for p in cell.get_polygons():
        by_layer[(p.layer, p.datatype)].append(p.points)

    # Global bounding box so every mask shares the same frame (they must align).
    bb = cell.bounding_box()
    if bb is None:
        print("ERROR: empty layout")
        sys.exit(1)
    bbox = bb

    manifest = {"topCell": cell.name, "units_um": True, "layers": []}
    items = []
    for (layer, dt), polys in by_layer.items():
        name = layer_name(layer, dt)
        items.append((name, layer, dt, polys))

    def sort_key(it):
        name = it[0]
        return (ORDER.index(name) if name in ORDER else len(ORDER), it[1], it[2])
    items.sort(key=sort_key)

    for name, layer, dt, polys in items:
        safe = name.replace(".", "_")
        render_layer(polys, bbox, os.path.join(out_dir, f"{safe}.dark.png"), dark=True)
        render_layer(polys, bbox, os.path.join(out_dir, f"{safe}.clear.png"), dark=False)
        render_svg(polys, bbox, os.path.join(out_dir, f"{safe}.svg"))
        manifest["layers"].append({
            "name": name, "layer": layer, "datatype": dt,
            "polygons": len(polys),
            "files": {
                "dark": f"{safe}.dark.png",
                "clear": f"{safe}.clear.png",
                "svg": f"{safe}.svg",
            },
        })
        print(f"  {name:24s} (l{layer}/d{dt})  {len(polys)} polys")

    # Combined colored preview (all layers, distinct colors).
    fig = plt.figure(figsize=(8.0, 8.0), dpi=150)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_facecolor("black")
    fig.patch.set_facecolor("black")
    cmap = plt.get_cmap("tab20")
    for idx, (name, layer, dt, polys) in enumerate(items):
        color = cmap(idx % 20)
        pc = PolyCollection(polys, facecolors=[color], edgecolors="none", alpha=0.7)
        ax.add_collection(pc)
    (xmin, ymin), (xmax, ymax) = bbox
    width_um = (xmax - xmin)
    height_um = (ymax - ymin)
    ax.set_xlim(xmin, xmax)
    ax.set_ylim(ymin, ymax)
    ax.set_aspect("equal")
    ax.axis("off")
    # Scale bar: a 10%-width segment, labeled with its PHYSICAL length at the
    # chosen magnification, so a printed mask can be sized correctly.
    bar_layout = 0.1 * width_um
    bar_phys_um = bar_layout * magnification
    bx0 = xmin + 0.05 * width_um
    by0 = ymin + 0.05 * height_um
    ax.plot([bx0, bx0 + bar_layout], [by0, by0], color="white", lw=3)
    label = f"{bar_phys_um:.1f} um" if bar_phys_um < 1000 else f"{bar_phys_um/1000:.2f} mm"
    ax.text(bx0, by0 + 0.02 * height_um, label, color="white", fontsize=9)
    fig.savefig(os.path.join(out_dir, "_preview.png"), facecolor="black")
    plt.close(fig)

    phys_w_um = width_um * magnification
    phys_h_um = height_um * magnification
    manifest["preview"] = "_preview.png"
    manifest["mode"] = mode
    manifest["magnification"] = round(magnification, 2)
    manifest["minFeatureUm"] = round(SKY130_MIN_FEATURE_UM * magnification, 3)
    manifest["dieUm"] = {"width": round(phys_w_um, 2), "height": round(phys_h_um, 2)}
    manifest["dieMm"] = {"width": round(phys_w_um / 1000, 3), "height": round(phys_h_um / 1000, 3)}
    if mode == "real":
        manifest["note"] = (
            "REAL 130 nm geometry. Min feature ~0.13 um — far below manual "
            "photolithography resolution. Use these for visualization, mask shops, "
            "and maskless aligners, NOT manual cleanroom fabrication."
        )
    else:
        manifest["note"] = (
            f"SCALED for manual fabrication: magnified {magnification:.0f}x so the "
            f"min feature is ~{manifest['minFeatureUm']:.1f} um (printable for "
            f"transparency-mask photolithography, etching, sputtering). The die "
            f"becomes ~{manifest['dieMm']['width']:.2f} x {manifest['dieMm']['height']:.2f} mm "
            "— practical only for small/simple designs. Topology and function are "
            "identical to the 130 nm layout."
        )
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"Wrote {len(items)} layers + preview to {out_dir} (mode={mode}, mag={magnification:.0f}x)")


if __name__ == "__main__":
    main()
