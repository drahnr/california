/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Manager {

/**
 * The Calendar Manager main window.
 */

public class Window : Toolkit.DeckWindow {
    private CalendarList calendar_list = new CalendarList();
    
    private Window(Gtk.Widget relative_to, Gdk.Point? for_location) {
        base (relative_to, for_location, null);
        
        deck.add_cards(iterate<Toolkit.Card>(calendar_list).to_array_list());
    }
    
    public static void display(Gtk.Widget relative_to, Gdk.Point? for_location) {
        Manager.Window instance = new Manager.Window(relative_to, for_location);
        instance.show_all();
    }
    
    public override bool key_release_event(Gdk.EventKey event) {
        // F2 with no modifiers means rename currenly selected item
        if (event.keyval != Gdk.Key.F2 || event.state != 0)
            return base.key_release_event(event);
        
        if (calendar_list.selected == null)
            return base.key_release_event(event);
        
        calendar_list.selected.rename();
        
        // don't propagate
        return true;
    }
}

}

