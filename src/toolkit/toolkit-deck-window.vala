/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A GtkPopover with special support for {@link Deck}s.
 */

public class DeckWindow : Gtk.Popover {
    public Deck deck { get; private set; }
    
    /**
     * See {@link Card.dismiss}
     */
    public signal void dismiss(bool user_request, bool final);
    
    public DeckWindow(Gtk.Widget rel_to, Gdk.Point? for_location, Deck? starter_deck) {
        Object (relative_to: rel_to);
        
        // treat "closed" signal as dismissal by user request
        closed.connect(() => {
            dismiss(true, true);
        });
        
        this.deck = starter_deck ?? new Deck();
        
        if (for_location != null) {
            Gdk.Rectangle for_location_rect = Gdk.Rectangle() { x = for_location.x, y = for_location.y,
                width = 1, height = 1 };
            pointing_to = for_location_rect;
        }
        
        deck.dismiss.connect(on_deck_dismissed);
        
        // store Deck in box so margin can be applied
        Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        box.margin = 4;
        box.add(deck);
        
        add(box);
    }
    
    ~DeckWindow() {
        deck.dismiss.disconnect(on_deck_dismissed);
    }
    
    private void on_deck_dismissed(bool user_request, bool final) {
        dismiss(user_request, final);
    }
}

}

