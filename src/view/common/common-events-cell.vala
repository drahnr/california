/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Common {

/**
 * A (generally) square cell which displays {@link Component.Event}s, one per line, with brief
 * time information and summary and a capped bar for all-day or day-spanning events.
 */

internal abstract class EventsCell : Gtk.EventBox, InstanceContainer {
    public const string PROP_DATE = "date";
    public const string PROP_NEIGHBORS = "neighbors";
    public const string PROP_TOP_LINE_TEXT = "top-line-text";
    public const string PROP_TOP_LINE_RGBA = "top-line-rgba";
    public const string PROP_SELECTED = "selected";
    
    private const double ROUNDED_CAP_RADIUS = 5.0;
    private const int POINTED_CAP_WIDTH_PX = 6;
    
    private const double DEGREES = Math.PI / 180.0;
    
    private const string KEY_TOOLTIP = "california-events-cell-tooltip";
    
    private const Calendar.WallTime.PrettyFlag PRETTY_TIME_FLAGS =
        Calendar.WallTime.PrettyFlag.OPTIONAL_MINUTES
        | Calendar.WallTime.PrettyFlag.BRIEF_MERIDIEM;
    
    private enum CapEffect {
        NONE,
        BLOCKED,
        ROUNDED,
        POINTED
    }
    
    /**
     * The {@link Calendar.Date} this {@link EventsCell} is displaying.
     */
    public Calendar.Date date { get; private set; }
    
    /**
     * The horizontal neighbors for this {@link EventsCell}.
     *
     * Since cells are designed to be displayed horizontally (say, 7 per week), each cell needs
     * to know the {@link Calendar.Date}s of its neighbors so they can arrange line numbers when
     * displaying all-day and day-spanning events.
     */
    public Calendar.DateSpan neighbors { get; private set; }
    
    /**
     * Top line (title or summary) text, drawn in {@link Palette.normal_font}.
     *
     * Set to empty string if space should be reserved but blank, null if not used and class may
     * use space to draw events.
     */
    public string? top_line_text { get; set; default = null; }
    
    /**
     * Color of {@link top_line_text}.
     */
    private Gdk.RGBA _top_line_rgba = Gdk.RGBA();
    public Gdk.RGBA top_line_rgba {
        get { return _top_line_rgba; }
        set { _top_line_rgba = value; queue_draw(); }
    }
    
    // to avoid lots of redraws, only queue_draw() if set changes value
    private bool _selected = false;
    public bool selected {
        get {
            return _selected;
        }
        
        set {
            if (_selected != value)
                queue_draw();
            
            _selected = value;
        }
    }
    
    /**
     * @inheritDoc
     */
    public int event_count { get { return sorted_events.size; } }
    
    /**
     * @inheritDoc
     */
    public Calendar.Span contained_span { get { return date; } }
    
    /**
     * {@link View.Palette} used by cell.
     *
     * The palette should be associated with the toplevel Gtk.Window this cell is contained within.
     */
    public View.Palette palette { get; private set; }
    
    private Gee.TreeSet<Component.Event> sorted_events = new Gee.TreeSet<Component.Event>(all_day_comparator);
    private Gee.HashMap<int, Component.Event> line_to_event = new Gee.HashMap<int, Component.Event>();
    private Gtk.DrawingArea canvas = new Gtk.DrawingArea();
    
    public EventsCell(View.Palette palette, Calendar.Date date, Calendar.DateSpan neighbors) {
        assert(date in neighbors);
        
        this.palette = palette;
        this.date = date;
        this.neighbors = neighbors;
        top_line_rgba = palette.day_in_range;
        
        // see query_tooltip() for implementation
        has_tooltip = true;
        
        // wrap the EventBox around the DrawingArea, which is the real widget of interest for this
        // class
        add(canvas);
        
        notify[PROP_TOP_LINE_TEXT].connect(queue_draw);
        
        palette.palette_changed.connect(queue_draw);
        Calendar.System.instance.is_24hr_changed.connect(on_24hr_changed);
        Calendar.System.instance.today_changed.connect(on_today_changed);
        
        canvas.draw.connect(on_draw);
    }
    
    ~EventsCell() {
        palette.palette_changed.disconnect(queue_draw);
        Calendar.System.instance.is_24hr_changed.disconnect(on_24hr_changed);
        Calendar.System.instance.today_changed.disconnect(on_today_changed);
    }
    
    /**
     * Subclasses must provide a translation of a {@link Calendar.Date} into a {@link EventsCell}
     * adjoining this one (in whatever container they're associated with).
     *
     * This allows for EventCells to communicate with each other to arrange line numbering for
     * all-day and day-spanning events.
     */
    protected abstract EventsCell? get_cell_for_date(Calendar.Date cell_date);
    
    // this comparator uses the standard Event comparator with one exception: if both Events require
    // solid span lines, it sorts the one(s) with the furthest out end dates to the top, to ensure
    // they are at the top of the drawn lines and prevent gaps and skips in the connected bars
    private static int all_day_comparator(Component.Event a, Component.Event b) {
        if (a == b)
            return 0;
        
        if (!a.is_day_spanning && !b.is_day_spanning)
            return a.compare_to(b);
        
        Calendar.DateSpan a_span = a.get_event_date_span(Calendar.Timezone.local);
        Calendar.DateSpan b_span = b.get_event_date_span(Calendar.Timezone.local);
        
        int compare = a_span.start_date.compare_to(b_span.start_date);
        if (compare != 0)
            return compare;
        
        compare = b_span.end_date.compare_to(a_span.end_date);
        if (compare != 0)
            return compare;
        
        // to stabilize
        return a.compare_to(b);
    }
    
    /**
     * Returns true if the point at x,y is within the {@link Cell}'s width and height.
     */
    public bool is_hit(int x, int y) {
        return x >= 0 && x < get_allocated_width() && y >= 0 && y < get_allocated_height();
    }
    
    /**
     * Returns the assigned line number for the event, -1 if not found in {@link Cell}.
     */
    public int get_line_for_event(Component.Event event) {
        Gee.MapIterator<int, Component.Event> iter = line_to_event.map_iterator();
        while (iter.next()) {
            if (iter.get_value().equal_to(event))
                return iter.get_key();
        }
        
        return -1;
    }
    
    public void change_date_and_neighbors(Calendar.Date date, Calendar.DateSpan neighbors) {
        assert(date in neighbors);
        
        if (!date.equal_to(this.date)) {
            this.date = date;
            
            // stored events are now bogus
            clear_events();
            queue_draw();
        }
        
        if (!neighbors.equal_to(this.neighbors)) {
            this.neighbors = neighbors;
            
            // need to reassign line numbers, as they depend on neighbors
            assign_line_numbers();
            queue_draw();
        }
    }
    
    public void clear_events() {
        line_to_event.clear();
        
        foreach (Component.Event event in sorted_events.to_array())
            internal_remove_event(event);
        
        queue_draw();
    }
    
    public void add_event(Component.Event event) {
        if (!sorted_events.add(event))
            return;
        
        // subscribe to interesting mutable properties
        event.notify[Component.Event.PROP_SUMMARY].connect(queue_draw);
        event.notify[Component.Event.PROP_DATE_SPAN].connect(on_span_updated);
        event.notify[Component.Event.PROP_EXACT_TIME_SPAN].connect(on_span_updated);
        
        assign_line_numbers();
        
        queue_draw();
    }
    
    private bool internal_remove_event(Component.Event event) {
        if (!sorted_events.remove(event))
            return false;
        
        event.notify[Component.Event.PROP_SUMMARY].disconnect(queue_draw);
        event.notify[Component.Event.PROP_DATE_SPAN].disconnect(on_span_updated);
        event.notify[Component.Event.PROP_EXACT_TIME_SPAN].disconnect(on_span_updated);
        
        return true;
    }
    
    public void remove_event(Component.Event event) {
        if (!internal_remove_event(event))
            return;
        
        assign_line_numbers();
        
        queue_draw();
    }
    
    /**
     * To be called by the owning widget when a calendar's visibility has changed.
     *
     * This causes event line numbers to be reassigned and thie {@link Cell} redrawn, if the
     * calendar in question has any events in this date.
     */
    public void notify_calendar_visibility_changed(Backing.CalendarSource calendar_source) {
        if (!traverse<Component.Event>(sorted_events).any((event) => event.calendar_source == calendar_source))
            return;
        
        // found one
        assign_line_numbers();
        queue_draw();
    }
    
    // Called internally by other Cells when (a) they're in charge of assigning a multi-day event
    // its line number for the week and (b) that line number has changed.
    private void notify_assigned_line_number_changed(Gee.Collection<Component.Event> events) {
        if (!traverse<Component.Event>(sorted_events).contains_any(events))
            return;
        
        assign_line_numbers();
        queue_draw();
    }
    
    // each event gets a line of the cell to draw in; this clears all assigned line numbers and
    // re-assigns from the sorted set of events, making sure holes are filled where possible ...
    // if an event starts in this cell or this cell is the first day of a week an event is in,
    // this cell is responsible for assigning a line number to it, which the other cells of the
    // same week will honor (so a continuous line can be drawn)
    private void assign_line_numbers() {
        Gee.HashMap<int, Component.Event> old_line_to_event = line_to_event;
        line_to_event = new Gee.HashMap<int, Component.Event>();
        
        // track each event whose line number this cell is responsible for assigning that gets
        // reassigned because of this
        Gee.ArrayList<Component.Event> reassigned = new Gee.ArrayList<Component.Event>();
        
        foreach (Component.Event event in sorted_events) {
            if (!event.calendar_source.visible)
                continue;
            
            bool notify_reassigned = false;
            if (event.is_day_spanning) {
                // get the first day of this week the event exists in ... if not the current cell's
                // date, get the assigned line number from the first day of this week the event
                // exists in
                Calendar.Date first_date = get_event_first_day_in_neighbors(event);
                if (!date.equal_to(first_date)) {
                    int event_line = -1;
                    EventsCell? cell = get_cell_for_date(first_date);
                    if (cell != null)
                        event_line = cell.get_line_for_event(event);
                    
                    if (event_line >= 0) {
                        assign_line_number(event_line, event);
                        
                        continue;
                    }
                } else {
                    // only worried about multi-day events being reassigned, as that's what effects
                    // other cells (i.e. when notifying of reassignment)
                    notify_reassigned = event.get_event_date_span(Calendar.Timezone.local).duration.days > 1;
                }
            } else if (!event.is_all_day) {
                // if timed event is in this date but started elsewhere, don't display (unless it
                // requires a span, above)
                Calendar.Date start_date = new Calendar.Date.from_exact_time(
                    event.exact_time_span.start_exact_time.to_timezone(Calendar.Timezone.local));
                if (!start_date.equal_to(date))
                    continue;
            }
            
            // otherwise, a timed event, a single-day event, or a multi-day event which starts here,
            // so assign
            int assigned = assign_line_number(-1, event);
            
            // if this cell assigns the line number and the event is not new and the number has changed,
            // inform all the other cells following this day's in the current week
            if (notify_reassigned && old_line_to_event.values.contains(event) && old_line_to_event.get(assigned) != event)
                reassigned.add(event);
        }
        
        if (reassigned.size > 0) {
            // only need to tell cells following this day's neighbors about the reassignment
            Calendar.DateSpan span = new Calendar.DateSpan(date.next(), neighbors.end_date).clamp_between(
                neighbors);
            
            foreach (Calendar.Date span_date in span) {
                EventsCell? cell = get_cell_for_date(span_date);
                if (cell != null && cell != this)
                    cell.notify_assigned_line_number_changed(reassigned);
            }
        }
    }
    
    private int assign_line_number(int force_line_number, Component.Event event) {
        // kinda dumb, but this prevents holes appearing in lines where, due to the shape of the
        // all-day events, could be filled
        int line_number = 0;
        if (force_line_number < 0) {
            while (line_to_event.has_key(line_number))
                line_number++;
        } else {
            line_number = force_line_number;
        }
        
        line_to_event.set(line_number, event);
        
        return line_number;
    }
    
    private void on_24hr_changed() {
        if (has_events)
            queue_draw();
    }
    
    private void on_today_changed(Calendar.Date old_today, Calendar.Date new_today) {
        // need to know re: redrawing background color to indicate current day
        if (date.equal_to(old_today) || date.equal_to(new_today))
            queue_draw();
    }
    
    private void on_span_updated(Object object, ParamSpec param) {
        Component.Event event = (Component.Event) object;
        
        // remove from cell if no longer in this day, otherwise remove and add again to sorted_events
        // to re-sort
        if (!(date in event.get_event_date_span(Calendar.Timezone.local))) {
            remove_event(event);
        } else if (sorted_events.remove(event)) {
            sorted_events.add(event);
            assign_line_numbers();
        }
        
        queue_draw();
    }
    
    public override bool query_tooltip(int x, int y, bool keyboard_mode, Gtk.Tooltip tooltip) {
        Component.Event? event = get_event_at(Gdk.Point() { x = x, y = y });
        if (event == null)
            return false;
        
        string? tooltip_text = event.get_data<string?>(KEY_TOOLTIP);
        if (String.is_empty(tooltip_text))
            return false;
        
        tooltip.set_text(tooltip_text);
        
        return true;
    }
    
    // Returns the first day of this cell's neighbors that the event is in ... this could be
    // the event's starting day or the first day of this week (i.e. Monday or Sunday), depending
    // on the definition of neighbors
    private Calendar.Date get_event_first_day_in_neighbors(Component.Event event) {
        // Remember: event start date may be before the date of any of this cell's neighbors
        Calendar.Date event_start_date = event.get_event_date_span(Calendar.Timezone.local).start_date;
        
        return (event_start_date in neighbors) ? event_start_date : neighbors.start_date;
    }
    
    /**
     * Override to draw borders at the right time in the layering.
     *
     * This keeps solid all-day bars on top of the borders, achieving an effect of continuation.
     */
    protected virtual void draw_borders(Cairo.Context ctx) {
    }
    
    private bool on_draw(Cairo.Context ctx) {
        // shade background of cell for selection or if today
        if (selected) {
            Gdk.cairo_set_source_rgba(ctx, palette.selection);
            ctx.paint();
        } else if (date.equal_to(Calendar.System.today)) {
            Gdk.cairo_set_source_rgba(ctx, palette.current_day);
            ctx.paint();
        }
        
        // draw borders now, before everything else (but after background color)
        ctx.save();
        draw_borders(ctx);
        ctx.restore();
        
        if (top_line_text != null)
            draw_line_of_text(ctx, -1, top_line_rgba, top_line_text, CapEffect.NONE, CapEffect.NONE);
        
        // walk the assigned line numbers for each event and draw
        Gee.MapIterator<int, Component.Event> iter = line_to_event.map_iterator();
        while (iter.next()) {
            Component.Event event = iter.get_value();
            Calendar.DateSpan date_span = event.get_event_date_span(Calendar.Timezone.local);
            
            bool display_text = true;
            if (event.is_day_spanning) {
                // only show the title if (a) the first day of an all-day event or (b) this is the
                // first day of a contiguous span of a multi-day event.  (b) handles the contingency of a
                // multi-day event starting in a previous week prior to the top of the current view
                display_text = date_span.start_date.equal_to(date) || neighbors.start_date.equal_to(date);
            }
            
            string text;
            if (display_text) {
                if (event.is_all_day) {
                    text = event.summary;
                } else {
                    Calendar.ExactTime local_start = event.exact_time_span.start_exact_time.to_timezone(
                        Calendar.Timezone.local);
                    text = "%s %s".printf(local_start.to_pretty_time_string(PRETTY_TIME_FLAGS), event.summary);
                }
            } else {
                text = "";
            }
            
            // use caps on both ends of all-day events depending whether this is the start, end,
            // or start/end of week of continuing event
            CapEffect left_effect = CapEffect.NONE;
            CapEffect right_effect = CapEffect.NONE;
            if (event.is_day_spanning) {
                if (date_span.start_date.equal_to(date))
                    left_effect = CapEffect.ROUNDED;
                else if (neighbors.start_date.equal_to(date))
                    left_effect = CapEffect.POINTED;
                else
                    left_effect = CapEffect.BLOCKED;
                
                if (date_span.end_date.equal_to(date))
                    right_effect = CapEffect.ROUNDED;
                else if (neighbors.end_date.equal_to(date))
                    right_effect = CapEffect.POINTED;
                else
                    right_effect = CapEffect.BLOCKED;
            }
            
            Pango.Layout layout = draw_line_of_text(ctx, iter.get_key(), event.calendar_source.color_as_rgba(),
                text, left_effect, right_effect);
            event.set_data<string?>(KEY_TOOLTIP, layout.is_ellipsized() ? text : null);
        }
        
        return true;
    }
    
    // Returns top y position of line; negative line numbers are treated as top line
    // The number is currently not clamped to the height of the widget.
    private int get_line_top_y(int line_number) {
        int y;
        if (line_number < 0) {
            // if no top line, line_number < 0 is bogus
            y = (top_line_text != null) ? Palette.TEXT_MARGIN_PX : 0;
        } else {
            y = Palette.TEXT_MARGIN_PX;
            
            // starting y of top line
            if (top_line_text != null)
                y += palette.normal_font_height_px + Palette.LINE_PADDING_PX;
            
            // add additional lines
            y += line_number * (palette.small_font_height_px + Palette.LINE_PADDING_PX);
        }
        
        return y;
    }
    
    // If line number is negative, the top line is drawn; otherwise, zero-based line numbers get
    // "regular" treatment
    private Pango.Layout draw_line_of_text(Cairo.Context ctx, int line_number, Gdk.RGBA rgba,
        string text, CapEffect left_effect, CapEffect right_effect) {
        bool is_reversed = (left_effect != CapEffect.NONE || right_effect != CapEffect.NONE);
        
        int left = 0;
        int right = get_allocated_width();
        int top = get_line_top_y(line_number);
        int bottom = top + palette.small_font_height_px;
        
        // use event color for text unless reversed, where it becomes the background color
        Gdk.cairo_set_source_rgba(ctx, rgba);
        if (is_reversed) {
            // draw background rectangle in spec'd color with text in white
            switch (right_effect) {
                case CapEffect.ROUNDED:
                    ctx.new_sub_path();
                    // sub 2 to avoid touching right calendar line
                    ctx.arc(right - 2 - ROUNDED_CAP_RADIUS, top + ROUNDED_CAP_RADIUS, ROUNDED_CAP_RADIUS,
                        -90.0 * DEGREES, 0 * DEGREES);
                    ctx.arc(right - 2 - ROUNDED_CAP_RADIUS, bottom - ROUNDED_CAP_RADIUS, ROUNDED_CAP_RADIUS,
                        0 * DEGREES, 90.0 * DEGREES);
                break;
                
                case CapEffect.POINTED:
                    ctx.move_to(right - POINTED_CAP_WIDTH_PX, top);
                    ctx.line_to(right - 1, top + (palette.small_font_height_px / 2));
                    ctx.line_to(right - POINTED_CAP_WIDTH_PX, bottom);
                break;
                
                case CapEffect.BLOCKED:
                default:
                    ctx.move_to(right, top);
                    ctx.line_to(right, bottom);
                break;
            }
            
            switch (left_effect) {
                case CapEffect.ROUNDED:
                    // add one to avoid touching cell to the left's right calendar line
                    ctx.arc(left + 1 + ROUNDED_CAP_RADIUS, bottom - ROUNDED_CAP_RADIUS, ROUNDED_CAP_RADIUS,
                        90.0 * DEGREES, 180.0 * DEGREES);
                    ctx.arc(left + 1 + ROUNDED_CAP_RADIUS, top + ROUNDED_CAP_RADIUS, ROUNDED_CAP_RADIUS,
                        180.0 * DEGREES, 270.0 * DEGREES);
                break;
                
                case CapEffect.POINTED:
                    ctx.line_to(left + POINTED_CAP_WIDTH_PX, bottom);
                    ctx.line_to(left + 1, top + (palette.small_font_height_px / 2));
                    ctx.line_to(left + POINTED_CAP_WIDTH_PX, top);
                break;
                
                case CapEffect.BLOCKED:
                default:
                    ctx.line_to(left, bottom);
                    ctx.line_to(left, top);
                break;
            }
            
            // fill with event color
            ctx.fill_preserve();
            
            // close path from last point (deals with capped and uncapped ends) and paint
            ctx.close_path();
            ctx.stroke ();
            
            // set to white for text
            Gdk.cairo_set_source_rgba(ctx, Gdk.RGBA() { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 });
        }
        
        // add a couple of pixels to the text margins if capped
        int left_text_margin = Palette.TEXT_MARGIN_PX + (left_effect != CapEffect.NONE ? 3 : 0);
        int right_text_margin = Palette.TEXT_MARGIN_PX + (right_effect != CapEffect.NONE ? 3 : 0);
        
        Pango.Layout layout = create_pango_layout(text);
        // Use normal font for very top line, small font for all others (see get_line_top_y())
        layout.set_font_description((line_number < 0)
            ? palette.normal_font
            : palette.small_font);
        layout.set_ellipsize(Pango.EllipsizeMode.END);
        layout.set_width((right - left - left_text_margin - right_text_margin) * Pango.SCALE);
        
        ctx.move_to(left_text_margin, top);
        Pango.cairo_show_layout(ctx, layout);
        
        return layout;
    }
    
    /**
     * Returns a hit result for {@link Component.Event}, if hit at all.
     *
     * The Gdk.Point must be relative to the widget's coordinate system.
     */
    public Component.Event? get_event_at(Gdk.Point point) {
        for (int line_number = 0; line_number < line_to_event.size; line_number++) {
            int y = get_line_top_y(line_number);
            if (point.y >= y && point.y < (y + palette.small_font_height_px))
                return line_to_event.get(line_number);
        }
        
        return null;
    }
}

}

