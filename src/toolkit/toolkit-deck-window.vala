/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A GtkDialog with no visible action area.
 *
 * This is designed for UI panes that want to control their own interaction with the user (in
 * particular, button placement) but need all the benefits interaction-wise of GtkDialog.
 *
 * It's expected this will go away when we move to GTK+ 3.12 and can use GtkPopovers for these
 * interactions.
 */

public class DeckWindow : Gtk.Popover {
    public Deck deck { get; private set; }
    
    public signal void dismiss(bool user_request, bool final);
    
    public DeckWindow(Gtk.Widget rel_to, Gdk.Point? for_location, Deck? starter_deck) {
        Object (relative_to: rel_to);
        
        this.deck = starter_deck ?? new Deck();
        
        if (for_location != null) {
            Gdk.Rectangle for_location_rect = Gdk.Rectangle() { x = for_location.x, y = for_location.y,
                width = 1, height = 1 };
            pointing_to = for_location_rect;
        }
        
        deck.dismiss.connect(on_deck_dismissed);
        
        add(deck);
    }
    
    ~DeckWindow() {
        deck.dismiss.disconnect(on_deck_dismissed);
    }
    
    private void on_deck_dismissed(bool user_request, bool final) {
        dismiss(user_request, final);
        if (final)
            destroy();
    }
}

}

