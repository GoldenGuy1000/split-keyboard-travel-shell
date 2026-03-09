// Parameters to be easily adjusted in the customizer
/* [3D Printing] */
// changes screw cutouts to be more printable
fdm_printing = true; // changes the screw counterbore to be more printable
    layer_height = 0.2; // to add one-layer rectangles to the counterbore

/* [Case] */
// Distance from the edge of the pcb to the outer wall
finger_space = 12;

wall_thickness = 1.5;

enable_outer_walls = true;

bottom_thickness = 2.8;
lower_height = 15 + bottom_thickness;
// height past the top of the keycaps
upper_height = 23 + bottom_thickness; 

// horizontal pcb tolerance in mm
pcb_tolerance = 1.5;


/* [Screws] */
screw_type = 2; // [2:M2]
// screw thread + slop
screw_thread_diameter = screw_type + 0.4;
    screw_thread_radius = screw_thread_diameter / 2;
 // fits my m2 screwheads
screw_head_diameter = 4;
    screw_head_radius = screw_head_diameter  / 2;

// counterbore depth
screw_head_height = 1.6;

/* [Feet Indents] */
enable_feet_indents = true;
silicon_dot_diameter = 6.4;
silicon_dot_indent_depth = 1;
silicon_dot_positions = [[21,-17],[145,9],[141,63],[10,55]];

/* [Magnets] */
enable_magnets = true;
// magnet diameter plus a little slop
magnet_diameter = 6.2; 
    magnet_radius = magnet_diameter / 2;
magnet_height = 2;
magnet_wall_thickness = 1.8;
// specified by outer-wall vertex and percent towards the next vertex
magnet_positions = [[0, 0.45], [4, 0.5], [9, 0.5], [10, 0.8]];

/* [Anti-Sheer] */
enable_anti_sheer = true;
sheer_sphere_radius = 3;
anti_sheer_offset_angle = 86;

// TODO: paramaterize the charging port & power switch holes

/* [Hidden] */
$fa = 1;
$fs = 0.4;

// Takes points and treats them as offsets from the sum of previous points
function _integral_rec(v, sum=0, i=0, arr=[]) = (i == len(v)) ? arr :
  let(
    nsum = sum + v[i]
  )
  _integral_rec(v, nsum, i+1, [each arr, nsum]);
integral = function (v) len(v)<1 ? [] : _integral_rec(v, v[0]-v[0]);

// Converts vectors in [angle,length] to [x,y] coordinates
function angle_len(v, i=0, arr=[]) = (i == len(v)) ? arr :
    let( angle = v[i][0] )
    let( length = v[i][1] )
    angle_len(v, i=i+1, arr=[each arr, [length*cos(angle), length*sin(angle)]]);

function translate_2d(v, points, i=0, arr=[]) = (i == len(points)) ? arr :
    translate_2d(v, points, i=i+1, arr=[each arr, [points[i][0] + v[0], points[i][1] + v[1]]]);

/// The outline of the Corne 3 PCB (specifically the wireless typeractive corne mx)
/// and note that the first point will just specify where the board starts drawing from (0, 0 or in this case 0,5)
pcb_points = integral(angle_len([
[0,5],[90,60],[0,20],[90,2.25],[0,19],[90,2.5],[0,19],[90,2.25],[0,18.25],[-90,2.25],[0,19],[-90,4.75],[0,38],[-90,56.39],[180,56],[235,18],[187,37.25],[210,18.5],[119.2,28.5] // overall dimensions are off ever so slightly so it's smoother to not have the last point
]));

// based off of the top left corner of the pcb, & taken from my fusion dimensions -- pcb_points[1] is a bit brittle here unfortunately
screw_points = translate_2d(pcb_points[1], [[39,-15], [39+33,-15-40], [25.5,-15-40-7.4], [39+76, -15-3.5], [39+76, -15-3.5-19]]);


// makin the top & side to hold our magnets & stuff
top_points = [for (i=[3:12]) pcb_points[i]];
side_points = [for (i=[12:13]) pcb_points[i]];
port_points = [for (i=[0:2]) pcb_points[i]];
thumb_points = [for (i=[14:18]) pcb_points[i]];

fingerspace_points = concat(
    translate_2d([0,finger_space],top_points),
    translate_2d([finger_space,0],side_points),
    [[top_points[0][0],side_points[len(side_points)-1][1]]]
);

outer_wall_points = concat(
    port_points,
    fingerspace_points,
    thumb_points
);

module fingerspace() {
    difference() {
        offset(pcb_tolerance+wall_thickness)
            polygon(points=fingerspace_points);
        offset(wall_thickness) pcb_area();
    }
}

module fingerspace_fill() {
    linear_extrude(lower_height) fingerspace();
}

module outer_walls() {
    module _outer_walls() {
        translate([0,0,lower_height])
        linear_extrude(upper_height - lower_height)
        difference() {
            offset(pcb_tolerance+wall_thickness)
                polygon(points=outer_wall_points);

            offset(pcb_tolerance)
                polygon(points=outer_wall_points);
        }
    }

    if (enable_outer_walls) {
    render() {
        difference() {
            _outer_walls();
            hand_access();
        }
    }
    }
}


module pcb_area() {
    offset(pcb_tolerance) polygon(points=pcb_points);
}

module pcb_bottom() {
    linear_extrude(bottom_thickness) pcb_area();
}

module screw(pos) {
    translate([each pos, -0.001]) union()
    {
        linear_extrude(bottom_thickness+0.1) circle(screw_thread_radius);
        linear_extrude(screw_head_height) circle(screw_head_radius);
        if (fdm_printing) {
            linear_extrude(screw_head_height+layer_height) intersection() {
                square([screw_head_diameter, screw_thread_diameter], center=true);
                circle(screw_head_radius);
            };
            linear_extrude(screw_head_height+layer_height*2) intersection() {
                square(screw_thread_diameter, center=true);
                circle(screw_head_radius);
            };
        }
    }
}

module screws() {
    for (pos=screw_points)
        screw(pos);
}

module inner_walls() {
    linear_extrude(lower_height)
    difference() {
        offset(wall_thickness) pcb_area();
        pcb_area();
    }
}

// radius must be less than or equal to half of depth, that's how spheres work
module beveled_hole(width, height, depth, radius, extra_extrusion=1) {
    module beveled_hole_side(width, depth, radius) {
        translate([0,     0    ]) sphere(radius);
        translate([width, 0    ]) sphere(radius);
        translate([0,     depth-radius*2]) sphere(radius);
        translate([width, depth-radius*2]) sphere(radius);
    }

    difference() {
    translate([0,-extra_extrusion,0]) cube([width, depth+2*extra_extrusion, height]);
    translate([0,radius,0]) {
        hull() beveled_hole_side(width, depth, radius);
        hull() rotate([0,-90]) beveled_hole_side(height, depth, radius);
        hull() translate([0,0,height]) beveled_hole_side(width, depth, radius);
        hull() translate([width,0,0]) rotate([0,-90]) beveled_hole_side(height, depth, radius);
    }
    }
}

module charge_port() {
    extra_depth = 0.1;
    translate([2.5,0,bottom_thickness + 4])
    translate(pcb_points[1] + [0,pcb_tolerance-extra_depth])
        beveled_hole(14, 8, wall_thickness+extra_depth*2, 0.6);
}

module power_switch_reset_access() {
    extra_depth = 0.1;
    translate([0,5,bottom_thickness + 1])
    translate(pcb_points[0] + [-(pcb_tolerance-extra_depth),0])
    rotate(90)
    beveled_hole(20, 8, wall_thickness+extra_depth*2, 0.6);
}

module magnet_pillar() {
    if (enable_magnets) {
    magnet_pillar_height = upper_height-lower_height;
    post_height = magnet_pillar_height - magnet_height; // height before magnet cutout

    difference() {
        cylinder(h=magnet_pillar_height,r=(magnet_diameter+magnet_wall_thickness)/2);
        translate([0,0,post_height]) cylinder(h=magnet_height+0.001,r=magnet_radius);
    }
    }
}


function rotate_90_cw(v) = [
     0*v[0] + 1*v[1],
    -1*v[0] + 0*v[1],
    0
];

module magnet_position(point, lerp=.5, flip=false) {
    point1 = fingerspace_points[point];
    point2 = fingerspace_points[point+1];

    normal = rotate_90_cw(point2 - point1);
    inward = normal/norm(normal);
    translate([0,0,lower_height])
    translate((pcb_tolerance + 0.1)*inward)
    translate(point1*(1-lerp) + point2*lerp)
    rotate([0,0,90-acos([1,0,0]*inward)])
    {
        magnet_pillar();
        angle1 = 90 - anti_sheer_offset_angle * (flip ? -1 : 1);
        angle2 = 90 + anti_sheer_offset_angle * (flip ? -1 : 1);
        dist = magnet_radius + sheer_sphere_radius + 0.6;
        translate([cos(angle1)*dist,sin(angle1)*dist,0]) anti_sheer_sphere(male=true);
        translate([cos(angle2)*dist,sin(angle2)*dist,0]) anti_sheer_sphere(male=false);
    }
}

module magnets(positions, flip) {
    for (i = [0 : len(positions)-1]) {
        point = positions[i][0];
        lerp  = positions[i][1];
        magnet_position(point, lerp, flip);
    }
}

module anti_sheer_sphere(male=true) {
    module base() { cylinder(h=upper_height-lower_height, r=sheer_sphere_radius); }
    if (enable_anti_sheer) {
    if (male) {
        base();
        translate([0,0,upper_height-lower_height]) sphere(sheer_sphere_radius - 0.5);
    }
    else { difference() {
        base();
        translate([0,0,upper_height-lower_height]) sphere(sheer_sphere_radius - 0.45);
    }}
    }
}


// frustum is used to cut out bevels for hand space
// points should be a list of 2d coordinates, the frustum is between p1 & p2
module frustum(points, p1, p2, bonus_x=0, bonus_y=0) {
    width = points[p2][0] - points[p1][0] + wall_thickness + pcb_tolerance + bonus_x;
    depth =  points[p1][1] - points[p2][1] + pcb_tolerance + wall_thickness + bonus_y;
    height = upper_height-lower_height;
    angle = 45;
    // formula derived by hand to convert angle into scale
    scale_x = 2*height / (abs(width) * tan(angle)) + 1;
    scale_y = 2*height / (abs(depth) * tan(angle)) + 1;

    translate([
        width/2 - pcb_tolerance - wall_thickness + points[p1][0],
        -depth/2 + points[p1][1],
        lower_height
    ])
    linear_extrude(
            height,
            scale=[scale_x,scale_y]
        )
        square([abs(width), abs(depth)], center=true);
}
module hand_access() {
    // bonus x & y are to cover the whole area since you need slightly different offsets for each
    // not my favorite ngl
    render() {
    frustum(pcb_points, 0, 17, bonus_x = 10);
    frustum(pcb_points, 17, 13, bonus_y = -wall_thickness);
    }
}

module silicon_dot_indent() {
    if (enable_feet_indents) {
    translate([0,0,silicon_dot_indent_depth-0.001])
    rotate([0,180,0])
    linear_extrude(silicon_dot_indent_depth, scale=1.25)
    circle(r=silicon_dot_diameter/2);
    }
}
module silicon_dot_indents() {
    for (point = silicon_dot_positions)
        translate(point) silicon_dot_indent();
}

module keyboard(flip=false) {
    magnets(magnet_positions, flip);
    difference() {
        union() { pcb_bottom(); inner_walls(); outer_walls(); fingerspace_fill(); };
        charge_port();
        power_switch_reset_access();
        screws();
        silicon_dot_indents();
    }
}

translate([0,-60,0]) rotate([0,0,180]) mirror([1,0,0]) keyboard(flip=true);
keyboard();

// roof() can do chamfers, but needs to be enabled first apparently


