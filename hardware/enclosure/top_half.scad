// ==========================================
// NOVA PAY EDC REPLICA - MASTER PROJECT FILE
// Optimized for Bambu Lab A1 Mini (No Supports, < 1 Hour)
// ==========================================

// --- GLOBAL DIMENSIONS ---
length = 120;
width = 70;
top_height = 20;     // Deep enough to clear ESP32 jumper wires
bottom_height = 8;
wall = 1.6;          // Fast printing (4 perimeters on 0.4mm nozzle)
radius = 5;
tolerance = 0.2;     // Snug friction fit gap

// Helper Module for Rounded Boxes (Keeps code clean)
module rounded_box(l, w, h, r) {
    hull() {
        translate([r, r, 0]) cylinder(h=h, r=r, $fn=50);
        translate([w-r, r, 0]) cylinder(h=h, r=r, $fn=50);
        translate([r, l-r, 0]) cylinder(h=h, r=r, $fn=50);
        translate([w-r, l-r, 0]) cylinder(h=h, r=r, $fn=50);
    }
}

// ==========================================
// 1. TOP HALF (FACEPLATE)
// ==========================================
module top_half() {
    screen_w = 34; 
    screen_h = 45;
    screen_offset_y = 20; 
    button_hole_d = 12.5; 
    button_spacing = 13.5;

    difference() {
        // Main Shell
        rounded_box(length, width, top_height, radius);
        
        // Hollow inside
        translate([wall, wall, wall])
            rounded_box(length - 2*wall, width - 2*wall, top_height, radius-1);
            
        // Screen Cutout
        translate([width/2 - screen_w/2, length/2 + screen_offset_y - screen_h/2, -1])
            cube([screen_w, screen_h, wall + 2]);
            
        // 5 Push Button Cutouts
        for(i=[-2:2]) {
            translate([width/2 + (i*button_spacing), 22, -1])
                cylinder(h=wall+2, d=button_hole_d, $fn=50);
        }
    }
}

// ==========================================
// 2. BOTTOM HALF (MOTHERBOARD & RFID TRAY)
// ==========================================
module bottom_half() {
    lip_height = 3;      
    lip_wall = 1.2; 
    usb_w = 12;
    usb_h = 6;
    usb_offset_y = 85; // Moved up to align with ESP32 in the Top Zone
    
    rfid_w = 40.5;
    rfid_l = 60.5;
    rfid_h = 4;
    
    union() {
        difference() {
            // Main Bottom Shell
            rounded_box(length, width, bottom_height, radius);
            
            // Hollow inside
            translate([wall, wall, wall])
                rounded_box(length - 2*wall, width - 2*wall, bottom_height, radius-1);
                
            // USB-C Port Cutout
            translate([width - wall - 1, usb_offset_y, wall + 0.5])
                cube([wall + 2, usb_w, usb_h]);
        }

        // Friction-Fit Lip
        translate([wall + tolerance, wall + tolerance, bottom_height])
        difference() {
            rounded_box(length - 2*(wall + tolerance), width - 2*(wall + tolerance), lip_height, radius - 1);
            
            translate([lip_wall, lip_wall, -1])
                rounded_box(length - 2*(wall + tolerance + lip_wall), width - 2*(wall + tolerance + lip_wall), lip_height + 2, radius - 2);
        }
        
        // RC522 Bracket (Centered X, Bottom Y)
        b_wall = 1.2;
        translate([(width - rfid_w) / 2, 10, wall]) 
        difference() {
            translate([-b_wall, -b_wall, 0])
                cube([rfid_w + 2*b_wall, rfid_l + 2*b_wall, rfid_h]);
            cube([rfid_w, rfid_l, rfid_h + 1]);
            // Huge center cutout for pins and saving plastic
            translate([3, 3, -1])
                cube([rfid_w - 6, rfid_l - 6, rfid_h + 2]);
        }
    }
}

// ==========================================
// 3. DESKTOP DOCK (KICKSTAND)
// ==========================================
module desktop_dock() {
    term_w = width + 1; // 1mm clearance 
    term_th = top_height + bottom_height + 1; 
    tilt = 20;

    difference() {
        hull() {
            translate([5, 5, 0]) cylinder(h=2, r=5, $fn=50);
            translate([term_w+5, 5, 0]) cylinder(h=2, r=5, $fn=50);
            translate([5, 60, 0]) cylinder(h=2, r=5, $fn=50);
            translate([term_w+5, 60, 0]) cylinder(h=2, r=5, $fn=50);
            
            translate([5, 50, 40]) cylinder(h=2, r=5, $fn=50);
            translate([term_w+5, 50, 40]) cylinder(h=2, r=5, $fn=50);
            
            translate([5, 5, 12]) cylinder(h=2, r=5, $fn=50);
            translate([term_w+5, 5, 12]) cylinder(h=2, r=5, $fn=50);
        }
        
        translate([5, 12, 8]) 
            rotate([tilt, 0, 0]) 
            cube([term_w, term_th, 60]);
            
        translate([15, 15, -1]) 
            cube([term_w - 20, 35, 30]);
    }
}

// ==========================================
// RENDER SECTION (Comment out what you don't need)
// ==========================================

// Faceplate
// top_half();

// Back Cover (Moved 80mm to the right for visibility)
//translate([80, 0, 0]) 
bottom_half();

// Dock (Moved 160mm to the right for visibility)
///translate([160, 0, 0]) 
//desktop_dock();