/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Week {

/**
 * A GTK container that holds the various {@link Pane}s for each day of thw week.
 *
 * Although this looks to be the perfect use of Gtk.Grid, some serious limitations with that widget
 * forced this implementation to fall back on the old "boxes within boxes" of GTK 2.0.
 * Specifically, the top-left cell in this widget must be a fixed width (the same as
 * {@link HourRunner}'s) and Gtk.Grid wouldn't let that occur, always giving it more space than it
 * needed (although, strangely, always honoring the requested width for HourRunner).  This ruined
 * the effect of an "empty" box in the top left corner where the date labels met the hour runner.
 *
 * The basic layout is a top row of date labels (with a spacer at the beginning, as mentioned)
 * with a scrollable box of {@link DayPane}s with an HourRunner on the left side which scrolls
 * as well.  This layout ensures the date labels are always visible as the user scrolls down the
 * time of day for all the panes.
 */

internal class Grid : Gtk.Box {
    public const string PROP_WEEK = "week";
    
    private const Calendar.Date.PrettyFlag DATE_LABEL_FLAGS =
        Calendar.Date.PrettyFlag.COMPACT | Calendar.Date.PrettyFlag.NO_TODAY;
    
    public weak Controller owner { get; private set; }
    
    /**
     * The calendar {@link Week} this {@link Grid} displays.
     */
    public Calendar.Week week { get; private set; }
    
    /**
     * Name (id) of {@link Grid}.
     *
     * This is for use in a Gtk.Stack.
     */
    public string id { owned get { return "%d:%s".printf(week.week_of_month, week.month_of_year.abbrev_name); } }
    
    private Backing.CalendarSubscriptionManager subscriptions;
    private Gee.HashMap<Calendar.Date, DayPane> date_to_panes = new Gee.HashMap<Calendar.Date, DayPane>();
    private Gee.HashMap<Calendar.Date, AllDayCell> date_to_all_day = new Gee.HashMap<Calendar.Date,
        AllDayCell>();
    private Toolkit.ButtonConnector instance_container_button_connector = new Toolkit.ButtonConnector();
    private Toolkit.ButtonConnector all_day_button_connector = new Toolkit.ButtonConnector();
    private Toolkit.ButtonConnector day_pane_button_connector = new Toolkit.ButtonConnector();
    private Toolkit.MotionConnector day_pane_motion_connector = new Toolkit.MotionConnector.button_only();
    private Toolkit.MotionConnector all_day_cell_motion_connector = new Toolkit.MotionConnector.button_only();
    private Gtk.ScrolledWindow scrolled_panes;
    private Gtk.Widget right_spacer;
    private bool vadj_init = false;
    private Scheduled? scheduled_update_subscription = null;
    private Scheduled? scheduled_realloc = null;
    
    public Grid(Controller owner, Calendar.Week week) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        
        this.owner = owner;
        this.week = week;
        
        // use a top horizontal box to properly space the spacer next to the horizontal grid of
        // day labels and all-day cells
        Gtk.Box top_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        pack_start(top_box, false, true, 8);
        
        // fixed size space in top left corner of overall grid
        Gtk.DrawingArea left_spacer = new Gtk.DrawingArea();
        left_spacer.set_size_request(HourRunner.REQUESTED_WIDTH, -1);
        left_spacer.draw.connect(on_draw_bottom_line);
        left_spacer.draw.connect(on_draw_left_spacer_right_border);
        top_box.pack_start(left_spacer, false, false, 0);
        
        // hold day labels and all-day cells in a non-scrolling horizontal grid
        Gtk.Grid top_grid = new Gtk.Grid();
        top_grid.column_homogeneous = true;
        top_grid.column_spacing = 0;
        top_grid.row_homogeneous = false;
        top_grid.row_spacing = 0;
        top_box.pack_start(top_grid, true, true, 0);
        
        // to line up with day panes grid below, need to account for the space of the ScrolledWindow's
        // scrollbar
        right_spacer = new Gtk.DrawingArea();
        right_spacer.draw.connect(on_draw_right_spacer_left_border);
        top_box.pack_end(right_spacer, false, false, 0);
        
        // hold Panes (DayPanes and HourRunner) in a scrolling Gtk.Grid
        Gtk.Grid pane_grid = new Gtk.Grid();
        pane_grid.column_homogeneous = false;
        pane_grid.column_spacing = 0;
        pane_grid.row_homogeneous = false;
        pane_grid.row_spacing = 0;
        
        // attach an HourRunner to the left side of the Panes grid
        pane_grid.attach(new HourRunner(this), 0, 1, 1, 1);
        
        // date labels across the top, week panes extending across the bottom ... start col at one
        // to account for spacer/HourRunner
        int col = 1;
        foreach (Calendar.Date date in week) {
            Gtk.Label date_label = new Gtk.Label(date.to_pretty_string(DATE_LABEL_FLAGS));
            // draw a line along the bottom of the label
            date_label.draw.connect(on_draw_bottom_line);
            top_grid.attach(date_label, col, 0, 1, 1);
            
            // All-day cells (for drawing all-day and day-spanning events) go between the date
            // label and the day panes
            AllDayCell all_day_cell = new AllDayCell(this, date);
            instance_container_button_connector.connect_to(all_day_cell);
            all_day_button_connector.connect_to(all_day_cell);
            all_day_cell_motion_connector.connect_to(all_day_cell);
            top_grid.attach(all_day_cell, col, 1, 1, 1);
            
            // save mapping
            date_to_all_day.set(date, all_day_cell);
            
            DayPane pane = new DayPane(this, date);
            pane.expand = true;
            instance_container_button_connector.connect_to(pane);
            day_pane_button_connector.connect_to(pane);
            day_pane_motion_connector.connect_to(pane);
            pane_grid.attach(pane, col, 1, 1, 1);
            
            // save mapping
            date_to_panes.set(date, pane);
            
            col++;
        }
        
        // place Panes grid into a GtkScrolledWindow
        scrolled_panes = new Gtk.ScrolledWindow(null, null);
        scrolled_panes.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_panes.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
        scrolled_panes.add(pane_grid);
        // connect_after to ensure border is last thing drawn
        scrolled_panes.draw.connect_after(on_draw_top_line);
        pack_end(scrolled_panes, true, true, 0);
        
        // connect scrollbar width to right_spacer (above) so it's the same width
        scrolled_panes.get_vscrollbar().realize.connect(on_realloc_right_spacer);
        scrolled_panes.get_vscrollbar().size_allocate.connect(on_realloc_right_spacer);
        
        // connect instance connectors button event signal handlers for click/double-clicked
        instance_container_button_connector.clicked.connect(on_instance_container_clicked);
        instance_container_button_connector.double_clicked.connect(on_instance_container_double_clicked);
        
        // connect to individual motion event handlers for different types of instance containers
        all_day_cell_motion_connector.button_motion.connect(on_all_day_cell_button_motion);
        day_pane_motion_connector.button_motion.connect(on_day_pane_motion);
        
        // connect to individual button released handlers for different types of instance containers
        all_day_button_connector.released.connect(on_all_day_cell_button_released);
        day_pane_button_connector.released.connect(on_day_pane_button_released);
        
        // set up calendar subscriptions for the week
        subscriptions = new Backing.CalendarSubscriptionManager(
            new Calendar.ExactTimeSpan.from_span(week, Calendar.Timezone.local));
        subscriptions.calendar_added.connect(on_calendar_added);
        subscriptions.calendar_removed.connect(on_calendar_removed);
        subscriptions.instance_added.connect(on_calendar_instance_added_or_altered);
        subscriptions.instance_altered.connect(on_calendar_instance_added_or_altered);
        subscriptions.instance_removed.connect(on_calendar_instance_removed);
        
        // only start now if owner is display this week, otherwise use timeout (to prevent
        // subscriptions all coming up at once) ... use distance from current week as a way to
        // spread out the timings, also assume that user will go forward rather than go backward,
        // so weeks in past get +1 dinged against them
        int diff = owner.week.difference(week);
        if (diff < 0)
            diff = diff.abs() + 1;
        
        if (diff != 0)
            diff = 300 + (diff * 100);
        
        scheduled_update_subscription = new Scheduled.once_after_msec(diff, () => {
            subscriptions.start_async.begin();
        });
        
        // watch for vertical adjustment to initialize to set the starting scroll position
        scrolled_panes.vadjustment.changed.connect(on_vadjustment_changed);
    }
    
    public void unselect_all() {
        foreach (AllDayCell day_cell in date_to_all_day.values)
            day_cell.selected = false;
        
        foreach (DayPane day_pane in date_to_panes.values)
            day_pane.clear_selection();
    }
    
    private void on_vadjustment_changed(Gtk.Adjustment vadj) {
        // wait for vadjustment to look like something reasonable; also, only do this once
        if (vadj.upper <= 1.0 || vadj_init)
            return;
        
        // scroll to 6am when first created, unless in the current date, in which case scroll to
        // current time
        Calendar.WallTime start_time = Calendar.System.today in week
            ? Calendar.System.now.to_wall_time()
            : new Calendar.WallTime(6, 0, 0);
        
        // scroll there
        scrolled_panes.vadjustment.value = date_to_panes.get(week.start_date).get_line_y(start_time);
        
        // don't do this again
        vadj_init = true;
    }
    
    private bool on_draw_top_line(Gtk.Widget widget, Cairo.Context ctx) {
        Palette.prepare_hairline(ctx, owner.palette.border);
        
        ctx.move_to(0, 0);
        ctx.line_to(widget.get_allocated_width(), 0);
        ctx.stroke();
        
        return false;
    }
    
    private bool on_draw_bottom_line(Gtk.Widget widget, Cairo.Context ctx) {
        int width = widget.get_allocated_width();
        int height = widget.get_allocated_height();
        
        Palette.prepare_hairline(ctx, owner.palette.border);
        
        ctx.move_to(0, height);
        ctx.line_to(width, height);
        ctx.stroke();
        
        return false;
    }
    
    // Draw the left spacer's right-hand line, which only goes up from the bottom to the top of the
    // all-day cell it's adjacent to
    private bool on_draw_left_spacer_right_border(Gtk.Widget widget, Cairo.Context ctx) {
        int width = widget.get_allocated_width();
        int height = widget.get_allocated_height();
        Gtk.Widget adjacent = date_to_all_day.get(week.start_date);
        
        Palette.prepare_hairline(ctx, owner.palette.border);
        
        ctx.move_to(width, height - adjacent.get_allocated_height());
        ctx.line_to(width, height);
        ctx.stroke();
        
        return false;
    }
    
    // Like on_draw_left_spacer_right_line, this line is for the right spacer's left border
    private bool on_draw_right_spacer_left_border(Gtk.Widget widget, Cairo.Context ctx) {
        int height = widget.get_allocated_height();
        Gtk.Widget adjacent = date_to_all_day.get(week.end_date);
        
        Palette.prepare_hairline(ctx, owner.palette.border);
        
        ctx.move_to(0, height - adjacent.get_allocated_height());
        ctx.line_to(0, height);
        ctx.stroke();
        
        return false;
    }
    
    private void on_realloc_right_spacer() {
        // need to do outside of allocation signal due to some mechanism in GTK that prevents resizes
        // while resizing
        scheduled_realloc = new Scheduled.once_at_idle(() => {
            right_spacer.set_size_request(scrolled_panes.get_vscrollbar().get_allocated_width(), -1);
        });
    }
    
    private void on_calendar_added(Backing.CalendarSource calendar) {
    }
    
    private void on_calendar_removed(Backing.CalendarSource calendar) {
    }
    
    private void on_calendar_instance_added_or_altered(Component.Instance instance) {
        Component.Event? event = instance as Component.Event;
        if (event == null)
            return;
        
        foreach (Calendar.Date date in event.get_event_date_span(Calendar.Timezone.local)) {
            if (event.is_day_spanning) {
                AllDayCell? all_day_cell = date_to_all_day.get(date);
                if (all_day_cell != null)
                    all_day_cell.add_event(event);
            } else {
                DayPane? day_pane = date_to_panes.get(date);
                if (day_pane != null)
                    day_pane.add_event(event);
            }
        }
    }
    
    private void on_calendar_instance_removed(Component.Instance instance) {
        Component.Event? event = instance as Component.Event;
        if (event == null)
            return;
        
        foreach (Calendar.Date date in event.get_event_date_span(Calendar.Timezone.local)) {
            if (event.is_day_spanning) {
                AllDayCell? all_day_cell = date_to_all_day.get(date);
                if (all_day_cell != null)
                    all_day_cell.remove_event(event);
            } else {
                DayPane? day_pane = date_to_panes.get(date);
                if (day_pane != null)
                    day_pane.remove_event(event);
            }
        }
    }
    
    internal AllDayCell? get_all_day_cell_for_date(Calendar.Date cell_date) {
        return date_to_all_day.get(cell_date);
    }
    
    private void on_instance_container_clicked(Toolkit.ButtonEvent details, bool guaranteed) {
        // only interested in unguaranteed clicks on the primary mouse button
        if (details.button != Toolkit.Button.PRIMARY || guaranteed)
            return;
        
        Common.InstanceContainer instance_container = (Common.InstanceContainer) details.widget;
        
        Component.Event? event = instance_container.get_event_at(details.press_point);
        if (event != null)
            owner.request_display_event(event, instance_container, details.press_point);
    }
    
    private void on_instance_container_double_clicked(Toolkit.ButtonEvent details, bool guaranteed) {
        // only interested in unguaranteed double-clicks on the primary mouse button
        if (details.button != Toolkit.Button.PRIMARY || guaranteed)
            return;
        
        Common.InstanceContainer instance_container = (Common.InstanceContainer) details.widget;
        
        // if an event is at this location, don't process
        if (instance_container.get_event_at(details.press_point) != null)
            return;
        
        // if a DayPane, use double-click to determine rounded time of the event's start
        DayPane? day_pane = instance_container as DayPane;
        if (day_pane != null) {
            // convert click into starting time on the day pane rounded down to the nearest half-hour
            Calendar.WallTime wall_time = day_pane.get_wall_time(details.press_point.y).round_down(
                30, Calendar.TimeUnit.MINUTE);
            
            Calendar.ExactTime start_time = new Calendar.ExactTime(Calendar.Timezone.local,
                day_pane.date, wall_time);
            
            owner.request_create_timed_event(
                new Calendar.ExactTimeSpan(start_time, start_time.adjust_time(1, Calendar.TimeUnit.HOUR)),
                day_pane, details.press_point);
            
            return;
        }
        
        // otherwise, an all-day-cell, so request an all-day event
        owner.request_create_all_day_event(instance_container.contained_span, instance_container,
            details.press_point);
    }
    
    private void on_day_pane_motion(Toolkit.MotionEvent details) {
        DayPane day_pane = (DayPane) details.widget;
        
        // only update selection as long as button is depressed
        if (details.is_button_pressed(Toolkit.Button.PRIMARY))
            day_pane.update_selection(day_pane.get_wall_time(details.point.y));
        else
            day_pane.clear_selection();
    }
    
    private bool on_day_pane_button_released(Gtk.Widget widget, Toolkit.Button button, Gdk.Point point,
        Gdk.EventType event_type) {
        if (button != Toolkit.Button.PRIMARY)
            return Toolkit.PROPAGATE;
        
        DayPane day_pane = (DayPane) widget;
        
        Calendar.ExactTimeSpan? selection_span = day_pane.get_selection_span();
        if (selection_span == null)
            return Toolkit.PROPAGATE;
        
        owner.request_create_timed_event(selection_span, widget, point);
        
        return Toolkit.STOP;
    }
    
    private AllDayCell? get_cell_at(AllDayCell widget, Gdk.Point widget_location) {
        // convert widget's coordinates into grid coordinates
        int grid_x, grid_y;
        if (!widget.translate_coordinates(this, widget_location.x, widget_location.y,
            out grid_x, out grid_y)) {
            return null;
        }
        
        // convert those coordinates into the day cell now being hovered over
        // TODO: Obviously a better hit-test could be done here
        foreach (AllDayCell day_cell in date_to_all_day.values) {
            int cell_x, cell_y;
            if (!translate_coordinates(day_cell, grid_x, grid_y, out cell_x, out cell_y))
                continue;
            
            if (day_cell.is_hit(cell_x, cell_y))
                return day_cell;
        }
        
        return null;
    }
    
    private void on_all_day_cell_button_motion(Toolkit.MotionEvent details) {
        if (!details.is_button_pressed(Toolkit.Button.PRIMARY))
            return;
        
        // widget is always the cell where the drag began, not ends
        AllDayCell start_cell = (AllDayCell) details.widget;
        
        // get the widget now being hovered over
        AllDayCell? hit_cell = get_cell_at(start_cell, details.point);
        if (hit_cell == null)
            return;
        
        // select everything from the start cell to the hit cell
        Calendar.DateSpan span = new Calendar.DateSpan(start_cell.date, hit_cell.date);
        foreach (AllDayCell day_cell in date_to_all_day.values)
            day_cell.selected = day_cell.date in span;
    }
    
    private bool on_all_day_cell_button_released(Gtk.Widget widget, Toolkit.Button button, Gdk.Point point,
        Gdk.EventType event_type) {
        if (button != Toolkit.Button.PRIMARY) {
            unselect_all();
            
            return Toolkit.PROPAGATE;
        }
        
        AllDayCell start_cell = (AllDayCell) widget;
        
        // only convert drag-and-release to new event if start is selected (this prevents single-clicks
        // from being turned into new events)
        if (!start_cell.selected) {
            unselect_all();
            
            return Toolkit.PROPAGATE;
        }
        
        // get widget button was released over
        AllDayCell? release_cell = get_cell_at(start_cell, point);
        if (release_cell == null) {
            unselect_all();
            
            return Toolkit.PROPAGATE;
        }
        
        // let the host unselect all once the event has been created, this keeps the selection on
        // the display until the user has completed
        owner.request_create_all_day_event(new Calendar.DateSpan(start_cell.date, release_cell.date),
            widget, point);
        
        return Toolkit.STOP;
    }
}

}

