/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Month {

/**
 * The {@link View.Controllable} for a Month View of the user's calendars.
 *
 * The Controller holds a GtkStack of {@link Grid}s which it "flips" back and forth through as
 * the user navigates the calendar.
 */

public class Controller : BaseObject, View.Controllable {
    public const string PROP_MONTH_OF_YEAR = "month-of-year";
    public const string PROP_PALETTE = "palette";
    
    public const string VIEW_ID = "month";
    
    // number of Grids to keep in GtkStack and cache (in terms of months) ... this should be an
    // even number, as it is halved to determine neighboring months depths
    private const int CACHE_NEIGHBORS_COUNT = 4;
    
    // MasterGrid holds the day of week labels and Month.Cells
    private class MasterGrid : Gtk.Grid, View.Container {
        private Controller _owner;
        public unowned View.Controllable owner { get { return _owner; } }
        
        public MasterGrid(Controller owner) {
            _owner = owner;
        }
    }
    
    /**
     * The month and year being displayed.
     *
     * Defaults to the current month and year.
     */
    public Calendar.MonthOfYear month_of_year { get; private set; }
    
    /**
     * @inheritDoc
     */
    public Calendar.FirstOfWeek first_of_week { get; set; }
    
    /**
     * @inheritDoc
     */
    public string id { get { return VIEW_ID; } }
    
    /**
     * @inheritDoc
     */
    public string title { get { return _("Month"); } }
    
    /**
     * @inheritDoc
     */
    public string current_label { get; protected set; }
    
    /**
     * @inheritDoc
     */
    public bool is_viewing_today { get; protected set; }
    
    /**
     * @inheritDoc
     */
    public Calendar.Date default_date { get; protected set; }
    
    /**
     * {@link View.Palette} for the entire view.
     */
    public View.Palette palette { get; private set; }
    
    private MasterGrid master_grid;
    private Gtk.Stack stack = new Gtk.Stack();
    private Toolkit.StackModel<Calendar.MonthOfYear> stack_model;
    private Calendar.MonthSpan cache_span;
    
    public Controller(View.Palette palette) {
        this.palette = palette;
        
        master_grid = new MasterGrid(this);
        master_grid.column_homogeneous = true;
        master_grid.column_spacing = 0;
        master_grid.row_homogeneous = false;
        master_grid.row_spacing = 0;
        master_grid.expand = true;
        
        stack.transition_duration = Toolkit.SLOW_STACK_TRANSITION_DURATION_MSEC;
        
        stack_model = new Toolkit.StackModel<Calendar.MonthOfYear>(stack,
            Toolkit.StackModel.OrderedTransitionType.SLIDE_LEFT_RIGHT, model_presentation,
            trim_presentation_from_cache, ensure_presentation_in_cache);
        
        // insert labels for days of the week across top of master grid
        for (int col = 0; col < Grid.COLS; col++) {
            Gtk.Label dow_label = new Gtk.Label(null);
            dow_label.margin_top = 2;
            dow_label.margin_bottom = 2;
            
            // update label if first-of-week changes
            int dow_col = col + Calendar.DayOfWeek.MIN;
            notify[PROP_FIRST_OF_WEEK].connect(() => {
                Calendar.DayOfWeek dow = Calendar.DayOfWeek.for_checked(dow_col, first_of_week);
                dow_label.label = dow.abbrev_name;
            });
            
            master_grid.attach(dow_label, col, 0, 1, 1);
        }
        
        // the stack is what flips between the month grids (it's inserted empty here, changes to
        // first_of_week are what fill the stack with Grids and select which to display)
        master_grid.attach(stack, 0, 1, Grid.COLS, 1);
        
        notify[PROP_MONTH_OF_YEAR].connect(on_month_of_year_changed);
        Calendar.System.instance.today_changed.connect(on_today_changed);
        
        // update now that signal handlers are in place ... do first_of_week first since more heavy
        // processing is done when month_of_year changes
        first_of_week = Calendar.FirstOfWeek.SUNDAY;
        month_of_year = Calendar.System.today.month_of_year();
    }
    
    ~Controller() {
        Calendar.System.instance.today_changed.disconnect(on_today_changed);
    }
    
    private Gtk.Widget model_presentation(Calendar.MonthOfYear moy, out string? id) {
        Grid grid = new Grid(this, moy);
        id = grid.id;
        
        return grid;
    }
    
    private bool trim_presentation_from_cache(Calendar.MonthOfYear moy, Calendar.MonthOfYear? visible_moy) {
        // always keep current month in cache
        if (moy.equal_to(Calendar.System.today.month_of_year()))
            return false;
        
        return !(moy in cache_span);
    }
    
    private Gee.Collection<Calendar.MonthOfYear>? ensure_presentation_in_cache(
        Calendar.MonthOfYear? visible_moy) {
        // convert cache span into a collection on months
        Gee.List<Calendar.MonthOfYear> months = cache_span.as_list();
        
        // add today's month
        months.add(Calendar.System.today.month_of_year());
        
        return months;
    }
    
    private unowned Grid? get_current_month_grid() {
        return (Grid?) stack.get_visible_child();
    }
    
    /**
     * @inheritDoc
     */
    public void next() {
        month_of_year = month_of_year.next();
    }
    
    /**
     * @inheritDoc
     */
    public void previous() {
        month_of_year = month_of_year.previous();
    }
    
    /**
     * @inheritDoc
     */
    public void today() {
        // since changing the date is expensive in terms of adding/removing subscriptions, only
        // update the property if it's actually different
        Calendar.MonthOfYear now = Calendar.System.today.month_of_year();
        if (!now.equal_to(month_of_year))
            month_of_year = now;
    }
    
    /**
     * @inheritDoc
     */
    public void unselect_all() {
        Grid? current_grid = get_current_month_grid();
        if (current_grid != null)
            current_grid.unselect_all();
    }
    
    /**
     * @inheritDoc
     */
    public View.Container get_container() {
        return master_grid;
    }
    
    private void update_is_viewing_today() {
        is_viewing_today = month_of_year.equal_to(Calendar.System.today.month_of_year());
    }
    
    private void on_today_changed() {
        // don't update view but indicate if it's still in view
        update_is_viewing_today();
    }
    
    private void on_month_of_year_changed() {
        current_label = month_of_year.full_name;
        update_is_viewing_today();
        
        // update cache span, splitting down the middle of the current month
        cache_span = new Calendar.MonthSpan(
            month_of_year.adjust(0 - (CACHE_NEIGHBORS_COUNT / 2)),
            month_of_year.adjust(CACHE_NEIGHBORS_COUNT / 2)
        );
        
        // show (and add if not present) the current month
        stack_model.show(month_of_year);
    }
    
    public override string to_string() {
        return "Month.Controller for %s".printf(month_of_year.to_string());
    }
}

}

