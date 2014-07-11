/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * RotatingButtonBox is a specialty widget for displaying groups ("families") of buttons, with each
 * family silding (rotating) into view when required.
 *
 * Each family of Gtk.Buttons are held in Gtk.ButtonBoxes.  They are always laid out horizontally
 * with an END layout style and fixed spacing.  This widget is designed specifically for buttons
 * which populate the bottom edge of a dialog or popover.
 *
 * Families are created on-demand.  The direction of them sliding into view is determined by the
 * order they are created, i.e. the first family created is to the "left" of subsequent families.
 *
 * Families are described by a string name.  Family names are case-sensitive.
 */

public class RotatingButtonBox : Gtk.Stack {
    public const string PROP_FAMILY = "family";
    
    public Gtk.Orientation ORIENTATION = Gtk.Orientation.HORIZONTAL;
    public Gtk.ButtonBoxStyle LAYOUT_STYLE = Gtk.ButtonBoxStyle.END;
    public int SPACING = 8;
    
    /**
     * The family name currently visible.
     */
    public string? family { get; set; }
    
    private Gee.HashMap<string, Gtk.ButtonBox> button_boxes = new Gee.HashMap<string, Gtk.ButtonBox>();
    
    public RotatingButtonBox() {
        homogeneous = true;
        transition_duration = SLOW_STACK_TRANSITION_DURATION_MSEC;
        transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        
        bind_property("visible-child-name", this, PROP_FAMILY,
            BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
    }
    
    /**
     * Pack a Gtk.Button at the start of a particular family, creating the family if necessary.
     *
     * See Gtk.Box.pack_start().
     */
    public void pack_start(string family, Gtk.Button button) {
        get_family_container(family).pack_start(button);
    }
    
    /**
     * Pack a Gtk.Button at the end of a particular family, creating the family if necessary.
     *
     * See Gtk.Box.pack_end().
     */
    public void pack_end(string family, Gtk.Button button) {
        get_family_container(family).pack_end(button);
    }
    
    /**
     * Direct access to the Gtk.ButtonBox holding the named family.
     *
     * If the family doesn't exist, it will be created.
     */
    public Gtk.ButtonBox get_family_container(string family) {
        if (button_boxes.has_key(family))
            return button_boxes.get(family);
        
        // create new family of buttons
        Gtk.ButtonBox button_box = new Gtk.ButtonBox(ORIENTATION);
        button_box.layout_style = LAYOUT_STYLE;
        button_box.spacing = SPACING;
        
        // add to internal lookup
        button_boxes.set(family, button_box);
        
        // add to Gtk.Stack using the family name
        add_named(button_box, family);
        
        return button_box;
    }
}

}

