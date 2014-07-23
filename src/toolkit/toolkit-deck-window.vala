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
    
    private bool preserve_mode;
    private bool forcing_mode = false;
    
    public DeckWindow(Gtk.Widget rel_to, Gdk.Point? for_location, Deck? starter_deck) {
        Object (relative_to: rel_to);
        
        preserve_mode = modal;
        
        // treat "closed" signal as dismissal by user request
        closed.connect(() => {
            dismiss(true, true);
        });
        
        notify["modal"].connect(on_modal_changed);
        
        this.deck = starter_deck ?? new Deck();
        
        if (for_location != null) {
            Gdk.Rectangle for_location_rect = Gdk.Rectangle() { x = for_location.x, y = for_location.y,
                width = 1, height = 1 };
            pointing_to = for_location_rect;
        }
        
        // because adding/removing cards can cause deep in Gtk.Widget the Popover to lose focus,
        // those operations can prematurely close the Popover.  Catching these signals allow for
        // DeckWindow to go modeless during the operation and not close.  (RotatingButtonBox has a
        // similar issue.)
        //
        // TODO: This is fixed in GTK+ 3.13.6.  When 3.14 is baseline requirement, this code can
        // be removed.
        deck.notify["transition-running"].connect(on_transition_running_changed);
        deck.adding_removing_cards.connect(on_adding_removing_cards);
        deck.added_removed_cards.connect(on_added_removed_cards);
        deck.dismiss.connect(on_deck_dismissed);
        
        // store Deck in box so margin can be applied
        Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        box.margin = 4;
        box.add(deck);
        
        add(box);
    }
    
    ~DeckWindow() {
        deck.notify["transition-running"].disconnect(on_transition_running_changed);
        deck.adding_removing_cards.disconnect(on_adding_removing_cards);
        deck.added_removed_cards.disconnect(on_added_removed_cards);
        deck.dismiss.disconnect(on_deck_dismissed);
    }
    
    // if the modal value changes, preserve it (unless it's changing because we're forcing it to
    // go modal/modeless during transitions we're attempting to work around)
    private void on_modal_changed() {
        if (!forcing_mode)
            preserve_mode = modal;
    }
    
    private void force_mode(bool modal) {
        forcing_mode = true;
        this.modal = modal;
        forcing_mode = false;
    }
    
    private void on_transition_running_changed() {
        force_mode(deck.transition_running ? false : preserve_mode);
    }
    
    private void on_adding_removing_cards() {
        force_mode(false);
    }
    
    private void on_added_removed_cards() {
        force_mode(preserve_mode);
    }
    
    private void on_deck_dismissed(bool user_request, bool final) {
        dismiss(user_request, final);
    }
}

}

