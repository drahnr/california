/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

/**
 * A modal window for selecting and managing {@link Activator.Instance} workflows.
 */

public class Window : Toolkit.DeckWindow {
    private Window(Gtk.Widget relative_to, Gdk.Point? for_location) {
        base (relative_to, for_location, null);
        
        // The Deck is pre-populated with each of their Cards, with the InstanceList jumping to
        // the right set when asked to (and acting as home)
        Gee.List<Toolkit.Card> cards = new Gee.ArrayList<Toolkit.Card>();
        cards.add(new InstanceList());
        foreach (Instance activator in activators)
            cards.add_all(activator.create_cards(null));
        
        deck.add_cards(cards);
    }
    
    public static void display(Gtk.Widget relative_to, Gdk.Point? for_location) {
        Activator.Window instance = new Activator.Window(relative_to, for_location);
        instance.show_all();
    }
}

}

