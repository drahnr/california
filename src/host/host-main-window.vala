/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * Primary application window.
 */

public class MainWindow : Gtk.ApplicationWindow {
    /**
     * Minimum width of the main window (to be usable).
     */
    public const int MIN_WIDTH = 800;
    
    /**
     * Default width of the main window (to be usable).
     *
     * This value is also set in the GSettings XML file.
     */
    public const int DEFAULT_WIDTH = 1024;
    
    /**
     * Minimum height of the main window (to be usable).
     */
    public const int MIN_HEIGHT = 600;
    
    /**
     * Default height of the main window (to be usable).
     *
     * This value is also set in the GSettings XML file.
     */
    public const int DEFAULT_HEIGHT = 768;
    
    private const string DETAILED_ACTION_QUICK_CREATE_EVENT = "win.quick-create-event";
    private const string ACTION_QUICK_CREATE_EVENT = "quick-create-event";
    private const string ACCEL_QUICK_CREATE_EVENT = "<Primary>n";
    
    private const string DETAILED_ACTION_JUMP_TO_TODAY = "win.jump-to-today";
    private const string ACTION_JUMP_TO_TODAY = "jump-to-today";
    private const string ACCEL_JUMP_TO_TODAY = "<Primary>t";
    
    private const string DETAILED_ACTION_NEXT = "win.next";
    private const string ACTION_NEXT = "next";
    private const string ACCEL_NEXT = "<Alt>Right";
    
    private const string DETAILED_ACTION_PREVIOUS = "win.previous";
    private const string ACTION_PREVIOUS = "previous";
    private const string ACCEL_PREVIOUS = "<Alt>Left";
    
    private const string DETAILED_ACTION_MONTH = "win.view-month";
    private const string ACTION_MONTH = "view-month";
    private const string ACCEL_MONTH = "<Ctrl>M";
    
    private const string DETAILED_ACTION_WEEK = "win.view-week";
    private const string ACTION_WEEK = "view-week";
    private const string ACCEL_WEEK = "<Ctrl>W";
    
    private const string DETAILED_ACTION_INCREASE_FONT = "win.increase-font";
    private const string ACTION_INCREASE_FONT = "increase-font";
    private const string ACCEL_INCREASE_FONT = "KP_Add";
    
    private const string DETAILED_ACTION_DECREASE_FONT = "win.decrease-font";
    private const string ACTION_DECREASE_FONT = "decrease-font";
    private const string ACCEL_DECREASE_FONT = "KP_Subtract";
    
    private const string DETAILED_ACTION_RESET_FONT = "win.reset-font";
    private const string ACTION_RESET_FONT = "reset-font";
    private const string ACCEL_RESET_FONT = "KP_Multiply";
    
    private static const ActionEntry[] action_entries = {
        { ACTION_QUICK_CREATE_EVENT, on_quick_create_event },
        { ACTION_JUMP_TO_TODAY, on_jump_to_today },
        { ACTION_NEXT, on_next },
        { ACTION_PREVIOUS, on_previous },
        { ACTION_MONTH, on_view_month },
        { ACTION_WEEK, on_view_week },
        { ACTION_INCREASE_FONT, on_increase_font },
        { ACTION_DECREASE_FONT, on_decrease_font },
        { ACTION_RESET_FONT, on_reset_font }
    };
    
    private Gtk.Button quick_add_button;
    private View.Palette palette;
    private View.Controllable month_view;
    private View.Controllable week_view;
    private View.Controllable? current_controller = null;
    private Gee.HashSet<Binding> current_bindings = new Gee.HashSet<Binding>();
    private Gtk.Stack view_stack = new Gtk.Stack();
    private Gtk.HeaderBar headerbar = new Gtk.HeaderBar();
    private Gtk.Button today = new Gtk.Button.with_label(_("_Today"));
    private Binding view_stack_binding;
    private Gee.HashSet<string> view_stack_ids = new Gee.HashSet<string>();
    private int window_width = -1;
    private int window_height = -1;
    
    public MainWindow(Application app) {
        Object (application: app);
        
        title = Application.TITLE;
        set_size_request(MIN_WIDTH, MIN_HEIGHT);
        set_default_icon_name(Application.ICON_NAME);
        
        set_default_size(Settings.instance.window_width, Settings.instance.window_height);
        if (Settings.instance.window_maximized)
            maximize();
        
        bool rtl = get_direction() == Gtk.TextDirection.RTL;
        
        add_action_entries(action_entries, this);
        Application.instance.add_accelerator(ACCEL_QUICK_CREATE_EVENT, DETAILED_ACTION_QUICK_CREATE_EVENT,
            null);
        Application.instance.add_accelerator(ACCEL_JUMP_TO_TODAY, DETAILED_ACTION_JUMP_TO_TODAY,
            null);
        Application.instance.add_accelerator(rtl ? ACCEL_PREVIOUS : ACCEL_NEXT, DETAILED_ACTION_NEXT,
            null);
        Application.instance.add_accelerator(rtl ? ACCEL_NEXT : ACCEL_PREVIOUS, DETAILED_ACTION_PREVIOUS,
            null);
        Application.instance.add_accelerator(ACCEL_MONTH, DETAILED_ACTION_MONTH, null);
        Application.instance.add_accelerator(ACCEL_WEEK, DETAILED_ACTION_WEEK, null);
        Application.instance.add_accelerator(ACCEL_INCREASE_FONT, DETAILED_ACTION_INCREASE_FONT, null);
        Application.instance.add_accelerator(ACCEL_DECREASE_FONT, DETAILED_ACTION_DECREASE_FONT, null);
        Application.instance.add_accelerator(ACCEL_RESET_FONT, DETAILED_ACTION_RESET_FONT, null);
        
        // view stack settings
        view_stack.homogeneous = true;
        view_stack.transition_duration = Toolkit.DEFAULT_STACK_TRANSITION_DURATION_MSEC;
        view_stack.transition_type = Gtk.StackTransitionType.SLIDE_UP_DOWN;
        
        // subscribe before adding so first add to initialize UI
        view_stack.notify["visible-child"].connect(on_view_changed);
        
        // create a View.Palette for all the hosted views ...
        palette = new View.Palette(this);
        
        // ... then create the hosted views
        month_view = new View.Month.Controller(palette);
        week_view = new View.Week.Controller(palette);
        
        // add views to view stack, first added is first shown
        add_controller(month_view);
        add_controller(week_view);
        
        // if not on Unity, use headerbar as the titlebar (removes window chrome) and provide close
        // button for users who might have trouble finding it otherwise
#if !ENABLE_UNITY
        // Unity doesn't support GtkHeaderBar-as-title-bar very well yet; when set, the main
        // window can't be resized no matter what additional GtkWindow properties are set
        set_titlebar(headerbar);
        headerbar.show_close_button = true;
#endif
        
        today.valign = Gtk.Align.CENTER;
        today.use_underline = true;
        today.tooltip_text = _("Jump to today's date (Ctrl+T)");
        today.set_action_name(DETAILED_ACTION_JUMP_TO_TODAY);
        
        Gtk.Button prev = new Gtk.Button.from_icon_name(rtl ? "go-previous-rtl-symbolic" : "go-previous-symbolic",
            Gtk.IconSize.MENU);
        prev.valign = Gtk.Align.CENTER;
        prev.tooltip_text = _("Previous (Alt+Left)");
        prev.set_action_name(DETAILED_ACTION_PREVIOUS);
        
        Gtk.Button next = new Gtk.Button.from_icon_name(rtl ? "go-next-rtl-symbolic" : "go-next-symbolic",
            Gtk.IconSize.MENU);
        next.valign = Gtk.Align.CENTER;
        next.tooltip_text = _("Next (Alt+Right)");
        next.set_action_name(DETAILED_ACTION_NEXT);
        
        Gtk.Box nav_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_buttons.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        nav_buttons.get_style_context().add_class(Gtk.STYLE_CLASS_RAISED);
        nav_buttons.pack_start(prev);
        nav_buttons.pack_end(next);
        
        // TODO:
        // Remove Gtk.StackSwitcher for a few reasons: (a) the buttons are kinda wide and
        // would like to conserve header bar space; (b) want to add tooltips to buttons; and (c)
        // want to move to icons at some point
        Gtk.StackSwitcher view_switcher = new Gtk.StackSwitcher();
        view_switcher.stack = view_stack;
        view_switcher.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        view_switcher.get_style_context().add_class(Gtk.STYLE_CLASS_RAISED);
        
        // pack left-side of window
        headerbar.pack_start(today);
        headerbar.pack_start(nav_buttons);
        headerbar.pack_start(view_switcher);
        
        quick_add_button = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.MENU);
        quick_add_button.valign = Gtk.Align.CENTER;
        quick_add_button.tooltip_text = _("Quick add event (Ctrl+N)");
        quick_add_button.set_action_name(DETAILED_ACTION_QUICK_CREATE_EVENT);
        
        Gtk.Button calendars = new Gtk.Button.from_icon_name("x-office-calendar-symbolic",
            Gtk.IconSize.MENU);
        calendars.valign = Gtk.Align.CENTER;
        calendars.tooltip_text = _("Calendars (Ctrl+L)");
        calendars.set_action_name(Application.DETAILED_ACTION_CALENDAR_MANAGER);
        
        Gtk.MenuButton window_menu = new Gtk.MenuButton();
        window_menu.valign = Gtk.Align.CENTER;
        window_menu.menu_model = Resource.load<MenuModel>("window-menu.interface", "window-menu");
        window_menu.image = new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU);
        
        // Vertically center all buttons and put them in a SizeGroup to handle situations where
        // the text button is smaller than the icons buttons due to language (i.e. Hebrew)
        // see https://bugzilla.gnome.org/show_bug.cgi?id=729771
        Gtk.SizeGroup size = new Gtk.SizeGroup(Gtk.SizeGroupMode.VERTICAL);
        size.add_widget(today);
        size.add_widget(prev);
        size.add_widget(next);
        size.add_widget(quick_add_button);
        size.add_widget(calendars);
        size.add_widget(window_menu);
        
        // pack right-side of window ... note that this was fixed in 3.12, reversing the order of
        // how widgets need to be packed at the end
#if GTK_312
        headerbar.pack_end(window_menu);
        headerbar.pack_end(calendars);
        headerbar.pack_end(quick_add_button);
#else
        headerbar.pack_end(quick_add_button);
        headerbar.pack_end(calendars);
        headerbar.pack_end(window_menu);
#endif
        
        Gtk.Box layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        // if on Unity, since headerbar is not the titlebar, need to pack it like any other widget
#if ENABLE_UNITY
        layout.pack_start(headerbar, false, true, 0);
#endif
        layout.pack_end(view_stack, true, true, 0);
        
        add(layout);
        
        // bind stack's visible child property to the settings for it, both ways ... because we want
        // to initialize with the settings, use it as the source w/ SYNC_CREATE
        view_stack_binding = Settings.instance.bind_property(Settings.PROP_CALENDAR_VIEW, view_stack,
            "visible-child-name", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL,
            transform_setting_to_calendar_view);
        
        // to prevent storing the different children's names as the widget is destroyed (cleared,
        // i.e. remove each one by one), unbind before that occurs
        view_stack.destroy.connect(() => { BaseObject.unbind_property(ref view_stack_binding); });
        
        // monitor Settings to adjust actions and such
        Settings.instance.notify[Settings.PROP_SMALL_FONT_PTS].connect(on_font_size_changed);
        Settings.instance.notify[Settings.PROP_NORMAL_FONT_PTS].connect(on_font_size_changed);
        on_font_size_changed();
    }
    
    ~MainWindow() {
        Settings.instance.notify[Settings.PROP_SMALL_FONT_PTS].disconnect(on_font_size_changed);
        Settings.instance.notify[Settings.PROP_NORMAL_FONT_PTS].disconnect(on_font_size_changed);
    }
    
    public bool is_window_maximized() {
        Gdk.Window? window = get_window();
        if (window == null)
            return false;
        
        return (window.get_state() & Gdk.WindowState.MAXIMIZED) != 0;
    }
    
    public override void unmap() {
        Settings.instance.window_width = window_width;
        Settings.instance.window_height = window_height;
        Settings.instance.window_maximized = is_window_maximized();
        
        base.unmap();
    }
    
    public override bool configure_event(Gdk.EventConfigure event) {
        // don't directly write to GSettings as these events can come in fast and furious,
        // wait for unmap() to write them out
        window_width = event.width;
        window_height = event.height;
        
        return base.configure_event(event);
    }
    
    // only allow known stack children ids through
    private bool transform_setting_to_calendar_view(Binding binding, Value source, ref Value target) {
        if (!view_stack_ids.contains(source.get_string()))
            return false;
        
        target = source;
        
        return true;
    }
    
    private void add_controller(View.Controllable controller) {
        view_stack_ids.add(controller.id);
        view_stack.add_titled(controller.get_container(), controller.id, controller.title);
        controller.get_container().show_all();
    }
    
    private unowned View.Container? current_view_container() {
        return (View.Container?) view_stack.get_visible_child();
    }
    
    private void on_view_changed() {
        View.Container? view_container = current_view_container();
        if (view_container != null && view_container.owner == current_controller)
            return;
        
        if (current_controller != null) {
            // signals
            current_controller.request_create_timed_event.disconnect(on_request_create_timed_event);
            current_controller.request_create_all_day_event.disconnect(on_request_create_all_day_event);
            current_controller.request_display_event.disconnect(on_request_display_event);
            
            // clear bindings to unbind all of them
            current_bindings.clear();
        }
        
        if (view_container != null) {
            current_controller = view_container.owner;
            
            // signals
            current_controller.request_create_timed_event.connect(on_request_create_timed_event);
            current_controller.request_create_all_day_event.connect(on_request_create_all_day_event);
            current_controller.request_display_event.connect(on_request_display_event);
            
            // bindings
            Binding binding = current_controller.bind_property(View.Controllable.PROP_CURRENT_LABEL,
                headerbar, "title", BindingFlags.SYNC_CREATE);
            current_bindings.add(binding);
            
            binding = current_controller.bind_property(View.Controllable.PROP_IS_VIEWING_TODAY, today,
                "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
            current_bindings.add(binding);
        }
    }
    
    private void show_deck(Gtk.Widget relative_to, Gdk.Point? for_location, Toolkit.Deck deck) {
        Toolkit.DeckWindow deck_window = new Toolkit.DeckWindow(this, deck);
        
        // when the dialog closes, reset View.Controllable state (selection is maintained while
        // use is viewing/editing interaction) and destroy widgets
        deck_window.deck.dismiss.connect(() => {
            current_controller.unselect_all();
            deck_window.hide();
            // give the dialog a change to hide before allowing other signals to fire, which may
            // invoke another dialog (prevents multiple dialogs on screen at same time)
            Toolkit.spin_event_loop();
        });
        
        deck_window.deck.failure.connect((msg) => {
            Application.instance.error_message(msg);
        });
        
        deck_window.show_all();
        deck_window.run();
        deck_window.destroy();
    }
    
    private void on_quick_create_event() {
        quick_create_event(null, quick_add_button, null);
    }
    
    private void on_jump_to_today() {
        current_controller.today();
    }
    
    private void on_next() {
        current_controller.next();
    }
    
    private void on_previous() {
        current_controller.previous();
    }
    
    private void on_view_month() {
        view_stack.set_visible_child(month_view.get_container());
    }
    
    private void on_view_week() {
        view_stack.set_visible_child(week_view.get_container());
    }
    
    private void on_increase_font() {
        Settings.instance.small_font_pts++;
        Settings.instance.normal_font_pts++;
    }
    
    private void on_decrease_font() {
        Settings.instance.small_font_pts--;
        Settings.instance.normal_font_pts--;
    }
    
    private void on_reset_font() {
        Settings.instance.small_font_pts = View.Palette.DEFAULT_SMALL_FONT_PTS;
        Settings.instance.normal_font_pts = View.Palette.DEFAULT_NORMAL_FONT_PTS;
    }
    
    private void on_font_size_changed() {
        ((SimpleAction) lookup_action(ACTION_INCREASE_FONT)).set_enabled(
            Settings.instance.small_font_pts < View.Palette.MAX_SMALL_FONT_PTS
            && Settings.instance.normal_font_pts < View.Palette.MAX_NORMAL_FONT_PTS);
        ((SimpleAction) lookup_action(ACTION_DECREASE_FONT)).set_enabled(
            Settings.instance.small_font_pts > View.Palette.MIN_SMALL_FONT_PTS
            && Settings.instance.normal_font_pts > View.Palette.MIN_NORMAL_FONT_PTS);
        ((SimpleAction) lookup_action(ACTION_RESET_FONT)).set_enabled(
            Settings.instance.small_font_pts != View.Palette.DEFAULT_SMALL_FONT_PTS
            && Settings.instance.normal_font_pts != View.Palette.DEFAULT_NORMAL_FONT_PTS);
    }
    
    private void on_request_create_timed_event(Calendar.ExactTimeSpan initial, Gtk.Widget relative_to,
        Gdk.Point? for_location) {
        Component.Event event = new Component.Event.blank();
        event.set_event_exact_time_span(initial);
        
        quick_create_event(event, relative_to, for_location);
    }
    
    private void on_request_create_all_day_event(Calendar.Span initial, Gtk.Widget relative_to,
        Gdk.Point? for_location) {
        Component.Event event = new Component.Event.blank();
        event.set_event_date_span(initial.to_date_span());
        
        quick_create_event(event, relative_to, for_location);
    }
    
    private void quick_create_event(Component.Event? initial, Gtk.Widget relative_to, Gdk.Point? for_location) {
        QuickCreateEvent quick_create = new QuickCreateEvent();
        
        CreateUpdateEvent create_update = new CreateUpdateEvent();
        create_update.is_update = false;
        
        CreateUpdateRecurring create_update_recurring = new CreateUpdateRecurring();
        
        EventTimeSettings event_time_settings = new EventTimeSettings();
        
        Toolkit.Deck deck = new Toolkit.Deck();
        deck.add_cards(
            iterate<Toolkit.Card>(quick_create, create_update, create_update_recurring, event_time_settings)
            .to_array_list()
        );
        
        // initialize the Deck with the initial event (if any)
        deck.go_home(initial);
        
        show_deck(relative_to, for_location, deck);
    }
    
    private void on_request_display_event(Component.Event event, Gtk.Widget relative_to,
        Gdk.Point? for_location) {
        ShowEvent show_event = new ShowEvent();
        
        CreateUpdateEvent create_update = new CreateUpdateEvent();
        create_update.is_update = true;
        
        CreateUpdateRecurring create_update_recurring = new CreateUpdateRecurring();
        
        EventTimeSettings event_time_settings = new EventTimeSettings();
        
        Toolkit.Deck deck = new Toolkit.Deck();
        deck.add_cards(
            iterate<Toolkit.Card>(show_event, create_update, create_update_recurring, event_time_settings)
            .to_array_list()
        );
        
        // "initialize" the Deck with the requested Event (because ShowEvent is first, it's home)
        deck.go_home(event);
        
        show_deck(relative_to, for_location, deck);
    }
}

}

