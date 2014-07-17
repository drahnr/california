/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A Card is a single pane of widget(s) in a {@link Deck}.
 *
 * The navigation of Cards is tracked within their Deck, and Cards can request navigation via their
 * various signals.  They're also notified when nevigation which affects them is made.
 */

public interface Card : Gtk.Widget {
    /**
     * Enumerates the various reasons a {@link Card} may be jumped to.
     */
    public enum Jump {
        /**
         * The {@link Card} was jumped to because it's home and {@link jump_home} was fired by
         * another Card.
         */
        HOME,
        /**
         * The {@link Card} was jumped to because another Card fired {@link jump_back} and this is
         * the previous Card in the {@link Deck}.
         */
        BACK,
        /**
         * The {@link Card} was jumped directly to by another Card, either by {@link card_id} or
         * by an object instance.
         *
         * @see jump_to_card
         * @see jump_to_card_by_name
         */
        DIRECT
    }
    
    /**
     * Each {@link Card} has its own identifier that should be unique within the {@link Deck}.
     *
     * In the Gtk.Stack, this is its name.
     */
    public abstract string card_id { get; }
    
    /**
     * A user-visible string that may be used elsewhere in the application.
     *
     * Gtk.StackSwitcher uses this title.  {@link Deck} does not use the title in any way.
     */
    public abstract string? title { get; }
    
    /** 
     * The widget the {@link Card} wants to be default when navigated to.
     *
     * The widget must have can-default set to true.
     */
    public abstract Gtk.Widget? default_widget { get; }
    
    /**
     * The widget the {@link Card} wants to have initial focus when navigated to.
     *
     * Focus is set after {@link default_widget} is handled, so if this widget has receives-default
     * set to true, it will get the default as well.
     *
     * The widget must have can-focus set to true.
     */
    public abstract Gtk.Widget? initial_focus { get; }
    
    /**
     * Returns the {@link Deck} this {@link Card} is registered to, if any.
     */
    public Deck? deck { get { return parent as Deck; } }
    
    /**
     * Fired when the {@link Card} wishes to jump to another Card in the same {@link Deck.}
     *
     * Each Card can accept a message which parameterizes its activation.  It's up to Cards
     * navigating to the new one to construct and pass an appropriate message.
     *
     * @see jump_to_card_by_name
     */
    public signal void jump_to_card(Card next, Value? message);
    
    /**
     * Fired when the {@link Card} wishes to jump to another Card by its name.
     *
     * @see jump_to_card
     */
    public signal void jump_to_card_by_name(string name, Value? message);
    
    /**
     * Fired when the {@link Card} wishes to jump to the previous Card in the {@link Deck}.
     *
     * Note that this Card's position in the navigation stack is lost; there is no "jump forward".
     */
    public signal void jump_back();
    
    /**
     * Fired when the {@link Card} wishes to jump to the first Card in the {@link Deck}.
     *
     * This clears the Deck's navigation stack, meaning {@link jump_back} will not return to
     * this Card.
     */
    public signal void jump_home();
    
    /**
     * Fired when the {@link Deck}'s work is cancelled, closed, failure, or a success, whether due
     * to programmatic reasons or by user request.
     *
     * user_request indicates if the dismissal is due to a user request or programmatic reasons.
     * closed indicates that there is no qualitative signal (i.e. {@link success}, {@link failure})
     * to follow.
     *
     * Implementing classes should use one of the notify_ methods to ensure that proper signal
     * order is maintained.
     */
    public signal void dismiss(bool user_request, bool final);
    
    /**
     * Fired when the {@link Deck}'s work has completed successfully.
     *
     * This should only be fired if the Deck requires valid input from the user to perform
     * some intensive operation.  Merely displaying information and closing the Deck
     * should simply fire {@link dismiss}.
     *
     * Implementing classes should use one of the notify_ methods to ensure that proper signal
     * order is maintained.
     */
    public signal void success();
    
    /**
     * Fired when the {@link Deck}'s work has failed to complete.
     *
     * This should only be fired if the Deck requires valid input from the user to perform
     * some intensive operation.  Merely displaying information and closing the Deck
     * should simply fire {@link dismiss}.
     *
     * Implementing classes should use one of the notify_ methods to ensure that proper signal
     * order is maintained.
     */
    public signal void failure(string? user_message);
    
    /**
     * Called by {@link Deck} when the {@link Card} has been activated, i.e. put to the "top" of
     * the Deck.
     *
     * message may be null even if the Card expects one; generally this means {@link jump_back}
     * or {@link jump_home} was invoked, resulting in this Card being activated.  The supplied
     * {@link Jump} reason is useful for context.  There are code paths where {@link Jump.HOME}
     * accepts a message; {@link Jump.BACK} will never supply a message.
     *
     * Due to some mechanism inside of GSignal or Vala, it's possible for a caller to pass null
     * that gets translated into a Value object holding a null pointer.  Deck will watch for this
     * situation and convert those Values into a null reference.  This means passing Value(null)
     * as a message is impossible.
     *
     * In order for this null-checking to work, the message must be holding a pointer, Object, or
     * a string.  Other types (including Vala-generated fundamental types!) are not safe-guarded.
     *
     * This is called before dealing with {@link default_widget} and {@link initial_focus}, so
     * changes to those properties in this call, if need be.
     */
    // TODO: Use a JumpContext object instead.
    public abstract void jumped_to(Card? from, Jump reason, Value? message);
    
    /**
     * Dismiss the {@link Deck} due to the user requesting it be closed or cancelled.
     */
    protected void notify_user_closed() {
        dismiss(true, true);
    }
    
    /**
     * Dismiss the {@link Deck} due to programmatic reasons.
     */
    protected void notify_aborted() {
        dismiss(false, true);
    }
    
    /**
     * Dismiss the {@link Deck} and notify that the user has successfully completed the task.
     */
    protected void notify_success() {
        dismiss(true, false);
        success();
    }
    
    /**
     * Dismiss the {@link Deck} and notify that the operation has failed.
     */
    protected void notify_failure(string? user_message) {
        dismiss(true, false);
        failure(user_message);
    }
    
    /**
     * Jump home or, if this {@link Card} is the home card, dismiss {@link Deck}.
     */
    protected void jump_home_or_user_closed() {
        if (deck.home == this)
            notify_user_closed();
        else
            jump_home();
    }
}

}
