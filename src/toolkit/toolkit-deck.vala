/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A Deck is a collection of {@link Card}s maintained within a Gtk.Stack.
 *
 * Cards control navigation through their various signals, which Deck monitors and acts upon.
 * It also notifies Cards of nagivation changes which affect them via their abstract methods.
 */

public class Deck : Gtk.Stack {
    /**
     * @inheritedDoc
     */
    public Gtk.Widget? default_widget { get { return null; } }
    
    /**
     * The number of {@link Card}s registered to the {@link Deck}.
     */
    public int size { get { return list.size; } }
    
    /**
     * All registered {@link Card}s returned as a read-only List.
     */
    public Gee.List<Card> cards { owned get { return list.read_only_view; } }
    
    /**
     * The home {@link Card}.
     */
    public Card? home { owned get { return (list.size > 0) ? list[0] : null; } }
    
    /**
     * The current displayed {@link Card}.
     */
    public Card? top { get; private set; default = null; }
    
    private Gee.List<Card> list = new Gee.LinkedList<Card>();
    private Gee.Deque<Card> navigation_stack = new Gee.LinkedList<Card>();
    private Gee.HashMap<string, Card> names = new Gee.HashMap<string, Card>();
    
    /**
     * Fired before {@link Card}s are added or removed.
     */
    public signal void adding_removing_cards(Gee.List<Card>? adding, Gee.Collection<Card>? removing);
    
    /**
     * Fired after {@link Card}s are added or removed.
     */
    public signal void added_removed_cards(Gee.List<Card>? added, Gee.Collection<Card>? removed);
    
    /**
     * @see Card.dismiss
     */
    public signal void dismiss(bool user_request, bool final);
    
    /**
     * @see Card.success
     */
    public signal void success();
    
    /**
     * @see Card.failure
     */
    public signal void failure(string? user_message);
    
    /**
     * Create a new {@link Deck}.
     *
     * By default the Deck configures the underlying Gtk.Stack to slide left and right, depending
     * on the position of the {@link Card}s.  This can be changed, but the recommended
     * transition types are SLIDE_LEFT_RIGHT and SLIDE_UP_DOWN.
     */
    public Deck() {
        transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        transition_duration = DEFAULT_STACK_TRANSITION_DURATION_MSEC;
        
        notify["visible-child"].connect(on_child_to_top);
    }
    
    ~Deck() {
        foreach (Card card in names.values)
            card.map.disconnect(on_card_mapped);
    }
    
    private void on_child_to_top() {
        // disconnect from previous top card and push onto nav stack
        if (top != null) {
            top.jump_to_card.disconnect(on_jump_to_card_instance);
            top.jump_to_card_by_name.disconnect(on_jump_to_card_by_name);
            top.jump_back.disconnect(on_jump_back);
            top.jump_home.disconnect(on_jump_home);
            top.dismiss.disconnect(on_dismiss);
            top.success.disconnect(on_success);
            top.failure.disconnect(on_failure);
            
            navigation_stack.offer_head(top);
            top = null;
        }
        
        // make new visible child top Card and connect to its signals
        top = visible_child as Card;
        if (top != null) {
            top.jump_to_card.connect(on_jump_to_card_instance);
            top.jump_to_card_by_name.connect(on_jump_to_card_by_name);
            top.jump_back.connect(on_jump_back);
            top.jump_home.connect(on_jump_home);
            top.dismiss.connect(on_dismiss);
            top.success.connect(on_success);
            top.failure.connect(on_failure);
        }
    }
    
    /**
     * A helper method for {@link add_cards}.
     */
    public void add_card(Card card) {
        add_cards(iterate<Card>(card).to_array_list());
    }
    
    /**
     * Add {@link Card}s to the {@link Deck}.
     *
     * Cards can be added in multiple batches, but the ordering is important as it dictates how
     * they're presented to the user via transitions and slides.
     *
     * The first Card added is the "home" Card.  The Deck will automatically show it first.
     */
    public void add_cards(Gee.List<Card> cards) {
        if (cards.size == 0)
            return;
        
        adding_removing_cards(cards, null);
        
        // if empty, first card is home and should be made visible when added
        bool set_home_visible = size == 0;
        
        // add each Card using the title if possible, otherwise by ID
        foreach (Card card in cards) {
            // each card must have a unique name
            assert(!String.is_empty(card.card_id));
            assert(!names.has_key(card.card_id));
            
            if (String.is_empty(card.title))
                add_named(card, card.card_id);
            else
                add_titled(card, card.card_id, card.title);
            
            names.set(card.card_id, card);
            
            // deal with initial_focus and default_widget when mapped, as the calls aren't
            // guaranteed to work during programmatic navigation (especially for the first card,
            // i.e. home)
            card.map.connect(on_card_mapped);
            
            // add in order to ensure order is preserved if sparsely removed later
            list.add(card);
        }
        
        if (set_home_visible && home != null) {
            set_visible_child(home);
            home.jumped_to(null, Card.Jump.HOME, null);
        }
        
        added_removed_cards(cards, null);
    }
    
    /**
     * Removes {@link Card}s from the {@link Deck}.
     *
     * If the {@link top} card is removed, the Deck will return {@link home}, clearing the
     * navigation stack in the process.
     */
    public void remove_cards(Gee.Collection<Card> cards) {
        bool displaying = top != null;
        
        adding_removing_cards(null, cards);
        
        foreach (Card card in cards) {
            if (!names.has_key(card.card_id)) {
                message("Card %s not found in Deck", card.card_id);
                
                continue;
            }
            
            card.map.disconnect(on_card_mapped);
            
            remove(card);
            
            if (top == card)
                top = null;
            
            navigation_stack.remove(card);
            names.unset(card.card_id);
            list.remove(card);
        }
        
        // if was displaying a Card and now not, jump home
        if (displaying && top == null && home != null) {
            navigation_stack.clear();
            set_visible_child(home);
            home.jumped_to(null, Card.Jump.HOME, null);
        }
        
        added_removed_cards(null, cards);
    }
    
    private Value? strip_null_value(Value? message) {
        if (message == null)
            return null;
        
        if (message.holds(typeof(string)))
            return message.get_string() != null ? message : null;
        
        if (message.holds(typeof(Object)))
            return message.get_object() != null ? message : null;
        
        if (message.holds(typeof(void*)))
            return message.get_pointer() != null ? message : null;
        
        return message;
    }
    
    /**
     * Force the {@link Deck} to jump to the {@link home} {@link Card}.
     *
     * In general, Deck avoids jumping to a Card if it's already displayed (on top).  However, for
     * this call it will call the Card's {@link Card.jumped_to} method and pass the supplied
     * message every time, even if already on top.  This allows for this call to be used for Deck
     * initialization.
     */
    public void go_home(Value? message) {
        if (home == null)
            return;
        
        // clear navigation stack, this acts as a kind of reset
        navigation_stack.clear();
        
        set_visible_child(home);
        home.jumped_to(null, Card.Jump.HOME, strip_null_value(message));
    }
    
    private void on_jump_to_card(Card card, Card next, Card.Jump reason, Value? message) {
        // do nothing if already visible
        if (get_visible_child() == next) {
            debug("Already showing card %s", next.card_id);
            
            return;
        }
        
        // do nothing if not registered with this Deck
        if (!names.values.contains(next)) {
            GLib.message("Card %s not registered with Deck", next.card_id);
            
            return;
        }
        
        set_visible_child(next);
        next.jumped_to(card, reason, strip_null_value(message));
    }
    
    private void on_jump_to_card_instance(Card card, Card next, Value? message) {
        on_jump_to_card(card, next, Card.Jump.DIRECT, message);
    }
    
    private void on_jump_to_card_by_name(Card card, string name, Value? message) {
        Card? next = names.get(name);
        if (next != null)
            on_jump_to_card(card, next, Card.Jump.DIRECT, message);
        else
            GLib.message("Card %s not found in Deck", name);
    }
    
    private void on_jump_back(Card card) {
        // if still not empty, next card is "back", so pop that off and jump to it
        if (!navigation_stack.is_empty)
            on_jump_to_card(card, navigation_stack.poll_head(), Card.Jump.BACK, null);
    }
    
    private void on_jump_home(Card card) {
        // jumping home clears the navigation stack
        navigation_stack.clear();
        
        if (home != null)
            on_jump_to_card(card, home, Card.Jump.HOME, null);
        else
            message("No home card in Deck");
    }
    
    private void on_dismiss(bool user_request, bool final) {
        dismiss(user_request, final);
    }
    
    private void on_success() {
        success();
    }
    
    private void on_failure(string? user_message) {
        failure(user_message);
    }
    
    private void on_card_mapped(Gtk.Widget widget) {
        Card card = (Card) widget;
        
        if (card.default_widget != null) {
            if (card.default_widget.can_default)
                card.default_widget.grab_default();
            else
                message("Card %s specifies default widget that cannot be default", card.card_id);
        }
    }
}

}

