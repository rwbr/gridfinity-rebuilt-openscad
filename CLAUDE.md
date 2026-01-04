# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gridfinity Rebuilt is an OpenSCAD parametric generator for [Gridfinity](https://www.youtube.com/watch?v=ra_9zU-mnl8) storage bins, baseplates, and accessories. The project recreates Zack Freedman's Gridfinity system using pure mathematical construction in OpenSCAD, enabling any size/configuration of bins.

## Development Environment

**Recommended**: Use [OpenSCAD development snapshots](https://openscad.org/downloads.html#snapshots) for dramatically faster rendering (seconds vs minutes for large bins).

## Running Tests

Tests use pytest with a custom OpenSCAD runner:
```bash
cd tests
pytest                           # Run all tests
pytest test_bins.py              # Run specific test file
pytest test_bins.py::TestBinHoles::test_no_holes  # Run single test
```

Tests generate images for visual verification and check that OpenSCAD code compiles without errors.

## Architecture

### Entry Point Files (Root Directory)
Top-level `.scad` files users open directly in OpenSCAD:
- `gridfinity-rebuilt-bins.scad` - Main bin generator with OpenSCAD Customizer parameters
- `gridfinity-rebuilt-baseplate.scad` - Baseplate generator
- `gridfinity-rebuilt-lite.scad` - Lightweight bins with hollow bases
- `gridfinity-spiral-vase.scad` - Vase-mode compatible bins/bases

### Core Modules (`src/core/`)
- `standard.scad` - **All Gridfinity constants** (dimensions, tolerances, hole sizes, tab/lip geometry). Include this in any file needing spec values.
- `bin.scad` - Bin construction API using struct-like syntax: `new_bin()` → `bin_render()` → `bin_subdivide()`
- `base.scad` - Base/floor generation with magnet/screw hole support
- `cutouts.scad` - Compartment cutters (`cut_compartment_auto`, `cut_chamfered_cylinder`)
- `wall.scad` - Stacking lip and wall profile generation
- `gridfinity-rebuilt-utility.scad` - Height calculation utilities (`height()`, `fromGridfinityUnits()`)
- `gridfinity-rebuilt-holes.scad` - Magnet/screw/refined hole options (`bundle_hole_options()`)

### Helper Modules (`src/helpers/`)
- `grid.scad` / `grid_element.scad` - Grid layout system for subdivisions and patterns
- `shapes.scad` - 2D/3D primitives (`rounded_square`, `sweep_rounded`)
- `generic-helpers.scad` - Utilities (`pattern_grid`, `pattern_circular`, `copy_mirror`)

### External Libraries (`src/external/`)
- `threads-scad/threads.scad` - Threaded hole generation (from [rcolyer/threads-scad](https://github.com/rcolyer/threads-scad))

## Key Patterns

### Bin Construction
Models are generated **subtractively**: solid bin first, then compartments/holes removed.

```openscad
include <src/core/standard.scad>
use <src/core/bin.scad>
use <src/core/cutouts.scad>

bin = new_bin(
    grid_size = [3, 2],          // bases wide × deep
    height_mm = height(6, 0),     // height calculation
    hole_options = bundle_hole_options(...)
);

bin_render(bin) {
    bin_subdivide(bin, [divx, divy]) {
        cut_compartment_auto(cgs());
    }
}
```

### Height Calculation
`gridz_define` parameter controls interpretation:
- `0`: Gridfinity units (7mm increments), excludes stacking lip
- `1`: Internal mm (excludes base + lip)
- `2`: External mm (excludes lip)
- `3`: External mm (includes lip)

### File Structure Convention
Each entry point file follows: Information → Parameters → Implementation → Construction → Examples

## OpenSCAD-Specific Notes

- Comments like `// .5` or `// [0:1:10]` after variables are Customizer hints
- Use `include` for constants/globals, `use` for modules only
- `$fa`/`$fs` special variables control mesh resolution
