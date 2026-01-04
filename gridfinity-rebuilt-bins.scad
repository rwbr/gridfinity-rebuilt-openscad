// ===== INFORMATION ===== //
/*
 IMPORTANT: rendering will be better in development builds and not the official release of OpenSCAD, but it makes rendering only take a couple seconds, even for comically large bins.
 the magnet holes can have an extra cut in them to make it easier to print without supports
 tabs will automatically be disabled when gridz is less than 3, as the tabs take up too much space
 base functions can be found in "gridfinity-rebuilt-utility.scad"
 comments like ' //.5' after variables are intentional and used by the customizer
 examples at end of file

 #BIN HEIGHT
 The original gridfinity bins had the overall height defined by 7mm increments.
 A bin would be 7*u millimeters tall with a stacking lip at the top of the bin (4.4mm) added onto this height.
 The stock bins have unit heights of 2, 3, and 6:
 * Z unit 2 -> 7*2 + 4.4 -> 18.4mm
 * Z unit 3 -> 7*3 + 4.4 -> 25.4mm
 * Z unit 6 -> 7*6 + 4.4 -> 46.4mm

 ## Note:
 The stacking lip provided here has a 0.6mm fillet instead of coming to a sharp point.
 Which has a height of 3.55147mm instead of the specified 4.4mm.
 This **has no impact on stacking height, and can be ignored.**

https://github.com/kennetek/gridfinity-rebuilt-openscad
*/

include <src/core/standard.scad>
use <src/core/gridfinity-rebuilt-utility.scad>
use <src/core/gridfinity-rebuilt-holes.scad>
use <src/core/bin.scad>
use <src/core/cutouts.scad>
use <src/helpers/generic-helpers.scad>
use <src/helpers/grid.scad>
use <src/helpers/grid_element.scad>
use <src/helpers/generic-helpers.scad>

// ===== PARAMETERS ===== //

/* [Setup Parameters] */
$fa = 4;
$fs = 0.25; // .01

/* [General Settings] */
// number of bases along x-axis
gridx = 3;
// number of bases along y-axis
gridy = 2;
// bin height. See bin height information and "gridz_define" below.
gridz = 6; //.1

// Half grid sized bins.  Implies "only corners".
half_grid = false;

/* [Height] */
// How "gridz" is used to calculate height.  Some exclude 7mm/1U base, others exclude ~3.5mm (4.4mm nominal) stacking lip.
gridz_define = 0; // [0:7mm increments - Excludes Stacking Lip, 1:Internal mm - Excludes Base & Stacking Lip, 2:External mm - Excludes Stacking Lip, 3:External mm]
// Overrides internal block height of bin (for solid containers). Leave zero for default height. Units: mm
height_internal = 0;
// snap gridz height to nearest 7mm increment
enable_zsnap = false;
// If the top lip should exist.  Not included in height calculations.
include_lip = true;

/* [Compartments] */
// number of X Divisions (set to zero to have solid bin)
divx = 1;
// number of Y Divisions (set to zero to have solid bin)
divy = 1;
// Leave zero for default. Units: mm
depth = 0;  //.1

/* [Cylindrical Compartments] */
// Use this instead of bins
cut_cylinders = false;
// diameter of cylindrical cut outs
cd = 10; // .1
// chamfer around the top rim of the holes
c_chamfer = 0.5; // .1
// Stagger cylinders in honeycomb pattern (for large diameter cylinders like 42mm+)
stagger_cylinders = false;
// Minimum wall thickness between cylinders (only for staggered mode)
c_spacing = 1; // .1

/* [Compartment Features] */
// the type of tabs
style_tab = 1; //[0:Full,1:Auto,2:Left,3:Center,4:Right,5:None]
// which divisions have tabs
place_tab = 0; // [0:Everywhere-Normal,1:Top-Left Division]
// scoop weight percentage. 0 disables scoop, 1 is regular scoop. Any real number will scale the scoop.
scoop = 1; //[0:0.1:1]

/* [Base Hole Options] */
// only cut magnet/screw holes at the corners of the bin to save uneccesary print time
only_corners = false;
//Use gridfinity refined hole style. Not compatible with magnet_holes!
refined_holes = true;
// Base will have holes for 6mm Diameter x 2mm high magnets.
magnet_holes = false;
// Base will have holes for M3 screws.
screw_holes = false;
// Magnet holes will have crush ribs to hold the magnet.
crush_ribs = true;
// Magnet/Screw holes will have a chamfer to ease insertion.
chamfer_holes = true;
// Magnet/Screw holes will be printed so supports are not needed.
printable_hole_top = true;
// Enable "gridfinity-refined" thumbscrew hole in the center of each base: https://www.printables.com/model/413761-gridfinity-refined
enable_thumbscrew = false;

hole_options = bundle_hole_options(refined_holes, magnet_holes, screw_holes, crush_ribs, chamfer_holes, printable_hole_top);

// ===== IMPLEMENTATION ===== //

bin1 = new_bin(
    grid_size = [gridx, gridy],
    height_mm = height(gridz, gridz_define, enable_zsnap),
    fill_height = height_internal,
    include_lip = include_lip,
    hole_options = hole_options,
    only_corners = only_corners || half_grid,
    thumbscrew = enable_thumbscrew,
    grid_dimensions = GRID_DIMENSIONS_MM / (half_grid ? 2 : 1)
);

echo(str(
    "\n",
    "Infill Dimensions*: ", bin_get_infill_size_mm(bin1), "\n",
    "Bounding Box: ", bin_get_bounding_box(bin1), "\n",
    "  *Excludes Stacking Lip Support Height (if stacking lip enabled)\n",
));
echo("Height breakdown:");
pprint(bin_get_height_breakdown(bin1));

bin_render(bin1) {
    if (cut_cylinders && stagger_cylinders) {
        // Quincunx pattern (like dots on dice "5") for large cylinders
        // Origin [0,0,0] is at the CENTER of the bin
        // c_spacing is MINIMUM spacing - actual may be larger for even distribution

        depth_real = depth > 0 ? depth : bin_get_infill_size_mm(bin1).z;
        infill_size = bin_get_infill_size_mm(bin1);

        // Outer radius of cutout (cylinder + chamfer)
        outer_r = cd/2 + c_chamfer;

        // Safe zone for cylinder CENTERS
        // Must maintain clearance from walls:
        // - outer_r: cylinder + chamfer radius
        // - c_spacing: minimum gap (same as between cylinders)
        // - STACKING_LIP_SIZE.x: lip protrudes into bin (if enabled)
        lip_clearance = include_lip ? STACKING_LIP_SIZE.x : 0;
        wall_margin = outer_r + c_spacing + lip_clearance;
        safe_w = infill_size.x - 2 * wall_margin;
        safe_h = infill_size.y - 2 * wall_margin;

        // Minimum center-to-center distance
        min_dist = cd + c_spacing;

        // How many cylinders fit in full rows (even rows)?
        full_row_count = max(1, floor(safe_w / min_dist) + 1);
        offset_row_count = max(1, full_row_count - 1);

        // Spread cylinders evenly across safe zone (not tight packing)
        actual_h_step = (full_row_count > 1) ? safe_w / (full_row_count - 1) : 0;

        // For staggered rows, calculate minimum vertical spacing
        // Two constraints:
        // 1. Diagonal distance must be >= min_dist
        //    diag = sqrt((h_step/2)² + v_step²) >= min_dist
        //    v_step >= sqrt(min_dist² - (h_step/2)²)
        // 2. Same-column cylinders (2 rows apart) must not overlap
        //    2 * v_step >= min_dist
        //    v_step >= min_dist / 2
        half_h = actual_h_step / 2;
        diagonal_v_step = (half_h >= min_dist) ? 0 : sqrt(min_dist * min_dist - half_h * half_h);
        same_col_v_step = min_dist / 2;
        min_v_step = max(diagonal_v_step, same_col_v_step);

        // How many rows fit?
        num_rows = (min_v_step > 0) ? max(1, floor(safe_h / min_v_step) + 1) : 1;

        // Spread rows evenly across safe zone
        actual_v_step = (num_rows > 1) ? safe_h / (num_rows - 1) : 0;

        // Pattern fills safe zone (margins are at outer_r from bin walls)
        pattern_w = (full_row_count > 1) ? safe_w : 0;
        pattern_h = (num_rows > 1) ? safe_h : 0;

        // Debug
        echo(str("Quincunx: safe=[", safe_w, ",", safe_h, "] min_dist=", min_dist));
        echo(str("  full_row=", full_row_count, " offset_row=", offset_row_count, " num_rows=", num_rows));
        echo(str("  h_step=", actual_h_step, " v_step=", actual_v_step));
        echo(str("  pattern=[", pattern_w, ",", pattern_h, "] margin=[", (safe_w-pattern_w)/2, ",", (safe_h-pattern_h)/2, "]"));

        for (row = [0 : num_rows - 1]) {
            is_offset = (row % 2 == 1);
            n_cyl = is_offset ? offset_row_count : full_row_count;

            // Calculate row width and center it
            row_width = (n_cyl - 1) * actual_h_step;
            start_x = -row_width / 2;

            // Center pattern vertically
            cy = -pattern_h / 2 + row * actual_v_step;

            for (col = [0 : n_cyl - 1]) {
                cx = start_x + col * actual_h_step;

                translate([cx, cy, 0])
                cut_chamfered_cylinder(cd/2, depth_real, c_chamfer);
            }
        }
    } else {
        // Standard grid pattern
        bin_subdivide(bin1, [divx, divy]) {
            depth_real = cgs(height=depth).z;
            if (cut_cylinders) {
                cut_chamfered_cylinder(cd/2, depth_real, c_chamfer);
            } else {
                cut_compartment_auto(
                    cgs(height=depth),
                    style_tab,
                    place_tab != 0,
                    scoop
                );
            }
        }
    }
}

// ===== EXAMPLES ===== //
/*
// 1x1 bin
bin_11 = new_bin([1, 1], fromGridfinityUnits(2));
// 3x3 bin
bin_33 = new_bin([3, 3], fromGridfinityUnits(6));

// Centered custom sized compartment.
translate([200, 200, 0])
bin_render(bin_11) {
    bin_translate(bin_11, [0.5, 0.5])
    compartment_cutter([10, 20,cgs().z]);
}

//Vary radius per child
translate([150, 200, 0])
bin_render(bin_11) {
    depth = bin_get_infill_size_mm(bin_11).z;
    bin_subdivide(bin_11, [3, 1]) {
        element = grid_element_current();
        r = 3 + grid_element_get_sequence_number(element);

        cut_chamfered_cylinder(r, depth);
    }
}

// One child per subdivision.
translate([150, 150, 0])
bin_render(bin_11) {
    depth = bin_get_infill_size_mm(bin_11).z;
    bin_subdivide(bin_11, [3, 1]) {
        translate([0, 0, -depth])
        child_per_element() {
            cylinder(r=3, h=depth);

            linear_extrude(depth)
            square(4, center=true);

            rotate([0, 0, 90])
            linear_extrude(depth)
            text("text", halign="center");
        }
    }
}

// 3x3 even spaced grid
translate([150, 0, 0])
bin_render(bin_33) {
    bin_subdivide(bin_33, [3, 3]) {
        cut_compartment_auto(cgs());
    }
}

// Compartments can be placed anywhere (this includes non-integer positions like 1/2 or 1/3). The grid is defined as [0, 0] being the bottom left corner of the bin, with each unit being 1 base long.
//  Use `bin_translate` to go to the correct coordinates within the bin.
//  Use `compartment_cutter(cgs([x, y]), center_top=false);` to cut a compartment of approximately size [x, y] bases.

translate([-150, 0, 0])
bin_render(bin_33) {
    bin_translate(bin_33, [0, 0])
    compartment_cutter(cgs([1.5, 0.5]), center_top=false);
    bin_translate(bin_33, [0, 0.5])
    compartment_cutter(cgs([1.5, 0.5]), center_top=false);
    bin_translate(bin_33, [0, 1])
    compartment_cutter(cgs([1.5, 0.5]), center_top=false);

    bin_translate(bin_33, [0, 1.5])
    compartment_cutter(cgs([0.5, 1.5]), center_top=false);
    bin_translate(bin_33, [0.5, 1.5])
    echo(cgs([0.5, 1.5]))
    compartment_cutter(cgs([0.5, 1.5]), center_top=false);
    bin_translate(bin_33, [1, 1.5])
    compartment_cutter(cgs([0.5, 1.5]), center_top=false);

    bin_translate(bin_33, [1.5, 0])
    compartment_cutter(cgs([1.5, 5/3]), center_top=false);
    bin_translate(bin_33, [1.5, 5/3])
    compartment_cutter(cgs([1.5, 4/3]), center_top=false);
}

// Compartments can overlap! This allows for weirdly shaped compartments, such as this "2" bin.
translate([0, 150, 0])
bin_render(bin_33) {
    bin_translate(bin_33, [0, 2])
    compartment_cutter(cgs([2, 1]), center_top=false);
    bin_translate(bin_33, [1, 0])
    compartment_cutter(cgs([1, 3]), center_top=false);
    bin_translate(bin_33, [1, 0])
    compartment_cutter(cgs([2, 1]), center_top=false);
    bin_translate(bin_33, [0, 0])
    compartment_cutter(cgs([1, 2]), center_top=false);
    bin_translate(bin_33, [2, 1])
    compartment_cutter(cgs([1, 2]), center_top=false);
}

// A pattern of three cylinderical holes.
translate([0, -150, 0])
bin_render(bin_33) {
    depth = bin_get_infill_size_mm(bin_33).z;
    bin_translate(bin_33, [0, 0])
    compartment_cutter(cgs([2, 3]), center_top=false);
    bin_translate(bin_33, [0, 0])
    compartment_cutter(cgs([3, 1]), center_top=false);

    bin_translate(bin_33, [2.5, 2])
    pattern_grid([1, 3], [42/2, 42/2], true, true) {
        // Cannot use `cgs` here!
        cut_chamfered_cylinder(5, depth);
    }
}

// You can use loops as well as the bin dimensions to make different parametric functions, such as this one, which divides the box into columns, with a small 1x1 top compartment and a long vertical compartment below
translate([150, -150, 0])
bin_render(bin_33) {
    gx = bin_get_bases(bin_33).x;
    for(i=[0:gx-1]) {
        bin_translate(bin_33, [i, 0])
        compartment_cutter(cgs([1, gx-1]), center_top=false);
        bin_translate(bin_33, [i, gx-1])
        compartment_cutter(cgs([1, 1]), center_top=false);
    }
}

// Pyramid scheme bin
bin_44 = new_bin([4, 4], fromGridfinityUnits(6));

translate([-200, -200, 0])
bin_render(bin_44) {
    gx = bin_get_bases(bin_44).x;
    gy = bin_get_bases(bin_44).y;
    for (i = [0:gx-1])
    for (j = [0:i])
    bin_translate(bin_44, [j*gx/(i+1), gy-i-1])
    compartment_cutter(cgs([gx/(i+1), 1]), center_top=false);
}
*/
