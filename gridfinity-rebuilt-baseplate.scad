// ===== INFORMATION ===== //
/*
 IMPORTANT: rendering will be better in development builds and not the official release of OpenSCAD, but it makes rendering only take a couple seconds, even for comically large bins.

https://github.com/kennetek/gridfinity-rebuilt-openscad

*/

include <src/core/standard.scad>
include <src/core/gridfinity-baseplate.scad>
use <src/core/gridfinity-rebuilt-utility.scad>
use <src/core/gridfinity-rebuilt-holes.scad>
use <src/helpers/generic-helpers.scad>
use <src/helpers/grid.scad>

// ===== PARAMETERS ===== //

/* [Setup Parameters] */
$fa = 8;
$fs = 0.25;

/* [General Settings] */
// number of bases along x-axis
gridx = 2;
// number of bases along y-axis
gridy = 2;

/* [Screw Together Settings - Defaults work for M3 and 4-40] */
// screw diameter
d_screw = 3.35;
// screw head diameter
d_screw_head = 5;
// screw spacing distance
screw_spacing = .5;
// number of screws per grid block
n_screws = 1; // [1:3]


/* [Fit to Drawer] */
// minimum length of baseplate along x (leave zero to ignore, will automatically fill area if gridx is zero)
distancex = 0;
// minimum length of baseplate along y (leave zero to ignore, will automatically fill area if gridy is zero)
distancey = 0;

// where to align extra space along x
fitx = 0; // [-1:0.1:1]
// where to align extra space along y
fity = 0; // [-1:0.1:1]


/* [Styles] */

// baseplate styles (0-2 compatible with connectable clips, 3-4 use screw-together instead)
style_plate = 0; // [0: thin, 1:weighted, 2:skeletonized, 3: screw together, 4: screw together minimal]


// hole styles
style_hole = 0; // [0:none, 1:countersink, 2:counterbore]

/* [Magnet Hole] */
// Baseplate will have holes for 6mm Diameter x 2mm high magnets.
enable_magnet = true;
// Magnet holes will have crush ribs to hold the magnet.
crush_ribs = true;
// Magnet holes will have a chamfer to ease insertion.
chamfer_holes = true;

hole_options = bundle_hole_options(refined_hole=false, magnet_hole=enable_magnet, screw_hole=false, crush_ribs=crush_ribs, chamfer=chamfer_holes, supportless=false);

/* [Connectable Clips] */
// Enable clip slots for connecting multiple baseplates (not compatible with screw-together styles)
enable_connectable = true;

// ===== IMPLEMENTATION ===== //

color("tomato")
gridfinityBaseplate([gridx, gridy], l_grid, [distancex, distancey], style_plate, hole_options, style_hole, [fitx, fity]);

// ===== CONNECTOR (angepasst an clip.stl) =====
module connector_profile() {
    width_top = 19.1;      // angepasst für clip.stl Passform
    width_middle = 12.5;
    height_top = 7.6;      // angepasst für clip.stl Passform
    height_middle = 13.7;  // angepasst für clip.stl Passform

    // L-Profil (nur mittlere und obere Stufe)
    polygon(points=[
        [0, 0],
        [width_middle, 0],
        [width_middle, height_middle],
        [width_top, height_middle],
        [width_top, height_middle + height_top],
        [0, height_middle + height_top]
    ]);
}

module connector_scaled() {
    depth = 200;  // verlängert von 150 auf 200 (skaliert: 15mm -> 20mm)
    rotate([90, 0, 0])
    translate([0, 0, -depth/2])  // zentriert entlang der Längsachse
    linear_extrude(height = depth)
        connector_profile();
}

// Place connectors at all clip slot positions
if (enable_connectable) {
    place_connectors(gridx, gridy, [true, true, true, true], l_grid);
}

// Module to place connectors at all clip slot positions
module place_connectors(gx, gy, edges, size) {
    half_x = gx * size / 2;
    half_y = gy * size / 2;

    // +X edge (right side) - connector faces inward
    if (edges[0]) {
        translate([half_x, 0, 1.05])
        rotate([0, 0, 180])
        place_connectors_edge(gy, size);
    }

    // +Y edge (back side) - connector faces inward
    if (edges[1]) {
        translate([0, half_y, 1.05])
        rotate([0, 0, -90])
        place_connectors_edge(gx, size);
    }

    // -X edge (left side) - connector faces inward
    if (edges[2]) {
        translate([-half_x, 0, 1.05])
        rotate([0, 0, 0])
        place_connectors_edge(gy, size);
    }

    // -Y edge (front side) - connector faces inward
    if (edges[3]) {
        translate([0, -half_y, 1.05])
        rotate([0, 0, 90])
        place_connectors_edge(gx, size);
    }
}

module place_connectors_edge(grid_count, size) {
    edge_length = grid_count * size;

    for (i = [0:grid_count-1]) {
        slot_pos = ((i + 0.5) * size) - (edge_length / 2);

        translate([0, slot_pos, 0])
        scale([0.075, 0.1, 0.075])
        color("tomato")
        connector_scaled();
    }
}

// ===== CLIP.STL zum Analysieren (ausgeblendet) =====
// translate([42, -11.1, 5.1])
// rotate([90, 0, 0])
// color("gold")
// import("clip.stl");


// ===== CONSTRUCTION ===== //

/**
 * @brief Create a baseplate.
 * @param grid_size_bases Number of Gridfinity bases.
 *        2d Vector. [x, y].
 *        Set to [0, 0] to auto calculate using min_size_mm.
 * @param length X,Y size of a single Gridfinity base.
 * @param min_size_mm Minimum size of the baseplate. [x, y]
 *                    Extra space is filled with solid material.
 *                    Enables "Fit to Drawer."
 * @param sp Baseplate Style
 * @param hole_options
 * @param sh Style of screw hole allowing the baseplate to be mounted to something.
 * @param fit_offset Determines where padding is added.
 */
module gridfinityBaseplate(grid_size_bases, length, min_size_mm, sp, hole_options, sh, fit_offset = [0, 0]) {

    assert(is_list(grid_size_bases) && len(grid_size_bases) == 2,
        "grid_size_bases must be a 2d list");
    assert(is_list(min_size_mm) && len(min_size_mm) == 2,
        "min_size_mm must be a 2d list");
    assert(is_list(fit_offset) && len(fit_offset) == 2,
        "fit_offset must be a 2d list");
    assert(grid_size_bases.x > 0 || min_size_mm.x > 0,
        "Must have positive x grid amount!");
    assert(grid_size_bases.y > 0 || min_size_mm.y > 0,
        "Must have positive y grid amount!");

    additional_height = calculate_offset(sp, hole_options[1], sh);

    // Final height of the baseplate. In mm.
    baseplate_height_mm = additional_height + BASEPLATE_HEIGHT;

    // Final size in number of bases
    grid_size = [for (i = [0:1])
        grid_size_bases[i] == 0 ? floor(min_size_mm[i]/length) : grid_size_bases[i]];

    // Final size of the base before padding. In mm.
    grid_size_mm = concat(grid_size * length, [baseplate_height_mm]);

    // Final size, including padding. In mm.
    size_mm = [
        max(grid_size_mm.x, min_size_mm.x),
        max(grid_size_mm.y, min_size_mm.y),
        baseplate_height_mm
    ];

    // Amount of padding needed to fit to a specific drawer size. In mm.
    padding_mm = size_mm - grid_size_mm;

    is_padding_needed = padding_mm != [0, 0, 0];

    //Convert the fit offset to percent of how much will be added to the positive axes.
    // -1 : 1 -> 0 : 1
    fit_percent_positive = [for (i = [0:1]) (fit_offset[i] + 1) / 2];

    padding_start_point = -grid_size_mm/2 -
        [
            padding_mm.x * (1 - fit_percent_positive.x),
            padding_mm.y * (1 - fit_percent_positive.y),
            -grid_size_mm.z/2
        ];

    corner_points = [
        padding_start_point + [size_mm.x, size_mm.y, 0],
        padding_start_point + [0, size_mm.y, 0],
        padding_start_point,
        padding_start_point + [size_mm.x, 0, 0],
    ];

    echo(str("Number of Grids per axes (X, Y)]: ", grid_size));
    echo(str("Final size (in mm): ", size_mm));
    if (is_padding_needed) {
        echo(str("Padding +X (in mm): ", padding_mm.x * fit_percent_positive.x));
        echo(str("Padding -X (in mm): ", padding_mm.x * (1 - fit_percent_positive.x)));
        echo(str("Padding +Y (in mm): ", padding_mm.y * fit_percent_positive.y));
        echo(str("Padding -Y (in mm): ", padding_mm.y * (1 - fit_percent_positive.y)));
    }

    screw_together = sp == 3 || sp == 4;
    minimal = sp == 0 || sp == 4;

    difference() {
        union() {
            // Baseplate itself
            difference() {
                translate(padding_start_point)
                cube(size_mm);
                // Replicated Single Baseplate piece
                pattern_grid(grid_size, [length, length], true, true) {
                    if (minimal) {
                        translate([0, 0, -TOLLERANCE/2])
                        baseplate_cutter([length, length], baseplate_height_mm+TOLLERANCE);
                    } else {
                        translate([0, 0, additional_height+TOLLERANCE/2])
                        baseplate_cutter([length, length]);

                        // Bottom/through pattern for the solid baseplates.
                        if (sp == 1) {
                            cutter_weight();
                        } else if (sp == 2 || sp == 3) {
                            translate([0,0,-TOLLERANCE])
                            linear_extrude(additional_height + (2 * TOLLERANCE))
                            profile_skeleton();
                        }

                        // Add holes to the solid baseplates.
                        hole_pattern(){
                            // Manget hole
                            translate([0, 0, additional_height+TOLLERANCE])
                            mirror([0, 0, 1])
                            block_base_hole(hole_options);

                            translate([0,0,-TOLLERANCE])
                            if (sh == 1) {
                                cutter_countersink();
                            } else if (sh == 2) {
                                cutter_counterbore();
                            }
                        }
                    }
                }
            }
        }

        // Round the outside corners (Including Padding)
        for(i = [0:len(corner_points) - 1]) {
                point = corner_points[i];
                translate([
                point.x + (BASEPLATE_OUTER_RADIUS * -sign(point.x)),
                point.y + (BASEPLATE_OUTER_RADIUS * -sign(point.y)),
                0
            ])
            rotate([0, 0, i*90])
            square_baseplate_corner(additional_height, true);
        }

        if (screw_together) {
            translate([0, 0, additional_height/2])
            cutter_screw_together(grid_size.x, grid_size.y, length);
        }

        // Connectable clip slots (not compatible with screw-together styles)
        if (enable_connectable) {
            assert(!screw_together, "Connectable clips are not compatible with screw-together baseplate styles (3, 4). Use style 0, 1, or 2.");
            cutter_connectable(grid_size.x, grid_size.y, [true, true, true, true], length, baseplate_height_mm, additional_height);
        }
    }
}

function calculate_offset(style_plate, enable_magnet, style_hole) =
    assert(style_plate >=0 && style_plate <=4)
    let (screw_together = style_plate == 3 || style_plate == 4)
    screw_together ? 6.75 :
    style_plate==0 ? 0 :
    style_plate==1 ? bp_h_bot :
    calculate_offset_skeletonized(enable_magnet, style_hole);

function calculate_offset_skeletonized(enable_magnet, style_hole) =
    h_skel + (enable_magnet ? MAGNET_HOLE_DEPTH : 0) +
    (
        style_hole==0 ? d_screw :
        style_hole==1 ? BASEPLATE_SCREW_COUNTERSINK_ADDITIONAL_RADIUS : // Only works because countersink is at 45 degree angle!
        BASEPLATE_SCREW_COUNTERBORE_HEIGHT
    );

module cutter_weight() {
    union() {
        linear_extrude(bp_cut_depth*2,center=true)
        square(bp_cut_size, center=true);
        pattern_circular(4)
        translate([0,10,0])
        linear_extrude(bp_rcut_depth*2,center=true)
        union() {
            square([bp_rcut_width, bp_rcut_length], center=true);
            translate([0,bp_rcut_length/2,0])
            circle(d=bp_rcut_width);
        }
    }
}
module hole_pattern(){
    pattern_circular(4)
    translate([l_grid/2-d_hole_from_side, l_grid/2-d_hole_from_side, 0]) {
        render();
        children();
    }
}

module cutter_countersink(){
    screw_hole(SCREW_HOLE_RADIUS + TOLLERANCE, 2*BASE_PROFILE_HEIGHT,
        false, BASEPLATE_SCREW_COUNTERSINK_ADDITIONAL_RADIUS);
}

module cutter_counterbore(){
    screw_radius = SCREW_HOLE_RADIUS + TOLLERANCE;
    counterbore_height = BASEPLATE_SCREW_COUNTERBORE_HEIGHT + 2*LAYER_HEIGHT;
    union(){
        cylinder(h=2*BASE_PROFILE_HEIGHT, r=screw_radius);
        difference() {
            cylinder(h = counterbore_height, r=BASEPLATE_SCREW_COUNTERBORE_RADIUS);
            make_hole_printable(screw_radius, BASEPLATE_SCREW_COUNTERBORE_RADIUS, counterbore_height);
        }
    }
}

/**
 * @brief Added or removed from the baseplate to square off or round the corners.
 * @param height Baseplate's height, excluding lip and clearance height.
 * @param subtract If the corner should be scaled to allow subtraction.
 */
module square_baseplate_corner(height=0, subtract=false) {
    assert(height >= 0);
    assert(is_bool(subtract));

    subtract_ammount = subtract ? TOLLERANCE : 0;

    translate([0, 0, -subtract_ammount])
    linear_extrude(height + BASEPLATE_HEIGHT + (2 * subtract_ammount))
    difference() {
        square(BASEPLATE_OUTER_RADIUS + subtract_ammount , center=false);
        // TOLLERANCE needed to prevent a gap
        circle(r=BASEPLATE_OUTER_RADIUS - TOLLERANCE);
    }
}

/**
 * @brief 2d Cutter to skeletonize the baseplate.
 * @param size Width/Length of a single baseplate.  Only set if deviating from the standard!
 * @example difference(){
 *              cube(large_number);
 *              linear_extrude(large_number+TOLLERANCE)
 *              profile_skeleton();
 *          }
 */
module profile_skeleton(size=l_grid) {
    l = baseplate_inner_size([size, size]).x;

    offset(r_skel)
    difference() {
        square(l-2*r_skel, center = true);

        hole_pattern()
        offset(MAGNET_HOLE_RADIUS+r_skel+2)
        square([l,l]);
    }
}

module cutter_screw_together(gx, gy, size = l_grid) {

    screw(gx, gy);
    rotate([0,0,90])
    screw(gy, gx);

    module screw(a, b) {
        copy_mirror([1,0,0])
        translate([a*size/2, 0, 0])
        pattern_grid([1, b], [1, size], true, true)
        pattern_grid([1, n_screws], [1, d_screw_head + screw_spacing], true, true)
        rotate([0,90,0])
        cylinder(h=size/2, d=d_screw, center = true);
    }
}

// ===== CONNECTABLE CLIP SLOTS ===== //

/**
 * @brief 2D profile of the clip slot (T-slot shape).
 * @details Narrow at top (surface), wide at bottom (for flanges).
 *          Centered on X-axis, Y=0 is surface, positive Y goes into material.
 */
module clip_slot_profile() {
    // T-slot profile: narrow opening, wider cavity below
    // Based on STEP file measurements + tolerance
    neck_half = CLIP_SLOT_NECK_WIDTH / 2;
    head_half = CLIP_SLOT_WIDTH / 2;

    // Transition depth (where neck meets head)
    transition_depth = 2.15 + CLIP_SLOT_TOLERANCE;

    // Profile points (right half, will be mirrored)
    points = [
        [0, 0],                              // Center top
        [neck_half, 0],                      // Right edge of narrow opening
        [neck_half, transition_depth],       // Down to transition
        [head_half, transition_depth + 0.3], // Out to wide section (small chamfer)
        [head_half, CLIP_SLOT_DEPTH],        // Down to bottom
        [0, CLIP_SLOT_DEPTH],                // Center bottom
    ];

    // Create symmetric polygon by mirroring
    left_points = [for (i = [len(points)-2:-1:1]) [-points[i].x, points[i].y]];
    all_points = concat(points, left_points);

    // Apply corner rounding
    offset(r = CLIP_SLOT_CORNER_RADIUS)
    offset(r = -CLIP_SLOT_CORNER_RADIUS)
    polygon(all_points);
}

/**
 * @brief Creates a single clip slot cutter (negative space).
 * @details Oriented to cut horizontally from edge.
 *          Slot runs along Y-axis (length), cuts into X-axis (depth).
 * @param height Height of the slot (should match baseplate height).
 */
module clip_slot_cutter(height = BASEPLATE_HEIGHT + 10) {
    // Rotate and extrude the profile along the slot length
    translate([0, 0, -TOLLERANCE])
    rotate([0, -90, 0])
    linear_extrude(CLIP_SLOT_DEPTH + TOLLERANCE)
    rotate([0, 0, 90])
    scale([1, height / CLIP_SLOT_LENGTH, 1])
    square([CLIP_SLOT_LENGTH, 1], center = true);

    // The actual T-slot profile extruded along the slot length
    translate([TOLLERANCE, 0, height / 2])
    rotate([90, 0, 0])
    rotate([0, 90, 0])
    linear_extrude(CLIP_SLOT_DEPTH + TOLLERANCE)
    clip_slot_profile();
}

/**
 * @brief Simpler clip slot cutter - rectangular with T-profile.
 * @param height Height to cut through.
 */
module clip_slot_cutter_simple(height) {
    // Main slot body - cut from edge inward
    translate([TOLLERANCE, 0, 0])
    rotate([0, -90, 0])
    linear_extrude(CLIP_SLOT_DEPTH + 2*TOLLERANCE)
    translate([0, 0, 0])
    clip_slot_profile_extruded(height);
}

/**
 * @brief 2D profile for extrusion (slot cross-section along edge).
 * @param height Height of the slot.
 */
module clip_slot_profile_extruded(height) {
    // Simple rectangle for the slot opening
    square([height + 2*TOLLERANCE, CLIP_SLOT_LENGTH], center = true);
}

/**
 * @brief Pattern clip slots along a single baseplate edge.
 * @param grid_count Number of grid units along this edge.
 * @param size Size of one grid unit (typically l_grid = 42).
 * @param height Height of the baseplate.
 * @details Places slots at grid boundaries only.
 */
module cutter_connectable_edge(grid_count, size, height) {
    // Number of internal grid boundaries = grid_count - 1
    // For a 2x2 baseplate, each edge has 1 internal boundary
    num_slots = grid_count - 1;

    if (num_slots > 0) {
        edge_length = grid_count * size;

        for (i = [1:num_slots]) {
            // Position at grid boundary
            slot_pos = (i * size) - (edge_length / 2);

            translate([0, slot_pos, 0])
            clip_slot_cutter_v2(height);
        }
    }
}

/**
 * @brief Clip slot cutter v2 - cleaner implementation.
 * @details Cuts a T-slot from the edge. Positioned at origin, cuts into +X.
 * @param height Total height to cut through.
 */
module clip_slot_cutter_v2(height) {
    neck_half = CLIP_SLOT_NECK_WIDTH / 2;
    head_half = CLIP_SLOT_WIDTH / 2;
    transition_depth = 2.15 + CLIP_SLOT_TOLERANCE;

    translate([TOLLERANCE, 0, -TOLLERANCE])
    rotate([0, -90, 0])
    linear_extrude(CLIP_SLOT_DEPTH + 2*TOLLERANCE) {
        // Slot profile in XY plane (X = height, Y = length along edge)
        hull() {
            // Narrow top section
            translate([0, -neck_half, 0])
            square([height + 2*TOLLERANCE, CLIP_SLOT_NECK_WIDTH]);
        }

        // Wide bottom section (the undercut for flanges)
        translate([0, -head_half, 0])
        square([transition_depth + TOLLERANCE, CLIP_SLOT_WIDTH]);
    }
}

/**
 * @brief Final clip slot cutter - stepped profile for clip insertion from above.
 * @param height Total height of the baseplate.
 * @param additional_height Height of the solid base section (below the lip).
 * @details The clip is inserted from ABOVE. The slot has two levels:
 *          - Upper section: narrow depth (for clip neck/stem)
 *          - Lower section: deeper (for clip flanges)
 *          This creates a step where the clip flanges rest.
 *
 *          Cross-section (looking at edge from outside):
 *          ─────────────────────▶│  <- top surface
 *          │                     │
 *          │       │─────────────▼  <- step (neck depth)
 *          │       │
 *          │       ▼─────────────▶│  <- bottom (flange depth)
 */
module clip_slot_cutter_final(height, additional_height) {
    slot_length = CLIP_SLOT_LENGTH;  // ~20mm along edge

    // Einfache rechteckige Lücke für Connector
    slot_depth = 6.0;  // Tiefe der Lücke

    // Cutter startet bei z=1.05 (oberhalb der unteren Schräge)
    cut_start_z = 1.05;
    slot_height = height - cut_start_z + TOLLERANCE;

    translate([0, -slot_length/2, cut_start_z]) {
        // Einfache rechteckige Lücke
        translate([-slot_depth, 0, 0])
        cube([slot_depth + TOLLERANCE, slot_length, slot_height]);
    }
}

/**
 * @brief Create clip slot cutters for selected baseplate edges.
 * @param gx Number of grid units along X axis.
 * @param gy Number of grid units along Y axis.
 * @param edges Which edges to add slots to [+X, +Y, -X, -Y].
 * @param size Size of one grid unit.
 * @param height Total height of the baseplate.
 * @param additional_height Height of the solid base section (below the lip).
 * @details The cutter module cuts in -X direction by default.
 *          We rotate it to cut toward center from each edge.
 */
module cutter_connectable(gx, gy, edges, size, height, additional_height) {
    half_x = gx * size / 2;
    half_y = gy * size / 2;

    // +X edge (right side) - need to cut in -X direction (toward center)
    // Cutter default is -X, so no rotation needed
    if (edges[0]) {
        translate([half_x, 0, 0])
        rotate([0, 0, 0])
        cutter_connectable_edge_final(gy, size, height, additional_height);
    }

    // +Y edge (back/top side) - need to cut in -Y direction (toward center)
    // Rotate 90° so -X becomes -Y
    if (edges[1]) {
        translate([0, half_y, 0])
        rotate([0, 0, 90])
        cutter_connectable_edge_final(gx, size, height, additional_height);
    }

    // -X edge (left side) - need to cut in +X direction (toward center)
    // Rotate 180° so -X becomes +X
    if (edges[2]) {
        translate([-half_x, 0, 0])
        rotate([0, 0, 180])
        cutter_connectable_edge_final(gy, size, height, additional_height);
    }

    // -Y edge (front/bottom side) - need to cut in +Y direction (toward center)
    // Rotate -90° so -X becomes +Y
    if (edges[3]) {
        translate([0, -half_y, 0])
        rotate([0, 0, -90])
        cutter_connectable_edge_final(gx, size, height, additional_height);
    }
}

/**
 * @brief Pattern clip slots along edge - ONE slot per grid cell, centered.
 * @param grid_count Number of grid cells along this edge.
 * @param size Size of one grid unit.
 * @param height Total height of the baseplate.
 * @param additional_height Height of the solid base section (below the lip).
 */
module cutter_connectable_edge_final(grid_count, size, height, additional_height) {
    // One slot per grid cell, centered within each cell
    edge_length = grid_count * size;

    for (i = [0:grid_count-1]) {
        // Center of each grid cell
        slot_pos = ((i + 0.5) * size) - (edge_length / 2);

        translate([0, slot_pos, 0])
        clip_slot_cutter_final(height, additional_height);
    }
}

// ===== CONNECTABLE CLIP GENERATOR ===== //

/**
 * @brief Generate a single connection clip.
 * @details The clip has a triangular head (fits in grid profile) and T-shaped base.
 */
module connectable_clip() {
    // Clip dimensions (slightly smaller than slot for fit)
    fit_tolerance = 0.1;
    clip_length = 19.6 - fit_tolerance;
    neck_half = (2.1 - fit_tolerance) / 2;
    head_half = (4.3 - fit_tolerance) / 2;
    clip_depth = 3.8 - fit_tolerance;
    transition = 2.15 - fit_tolerance/2;

    // Triangular head height (sits in grid profile)
    head_height = 2.5;

    linear_extrude(clip_length, center = true) {
        // T-shaped base
        polygon([
            // Narrow stem
            [-neck_half, 0],
            [-neck_half, -transition],
            // Wide flange
            [-head_half, -transition - 0.2],
            [-head_half, -clip_depth],
            [head_half, -clip_depth],
            [head_half, -transition - 0.2],
            // Back to stem
            [neck_half, -transition],
            [neck_half, 0],
            // Triangular head
            [head_half, 0],
            [0, head_height],
            [-head_half, 0],
        ]);
    }
}

/**
 * @brief Generate multiple clips for printing.
 * @param count Number of clips.
 * @param spacing Space between clips.
 */
module connectable_clips(count = 4, spacing = 25) {
    for (i = [0:count-1]) {
        translate([i * spacing, 0, 0])
        rotate([90, 0, 0])
        connectable_clip();
    }
}

