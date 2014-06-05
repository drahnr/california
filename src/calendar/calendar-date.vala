/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable representation of a single date in time (year/month/day).
 *
 * This is primarily a GObject-ification of GLib's Date struct, with the added restriction that
 * this class is immutable.  This means this object is incapable of representing a DMY prior to
 * Year 1 (BCE).
 *
 * GLib.Date has many powerful features for representing a calendar day, but it's interface is
 * inconvenient when working in Vala.  It can also exist in an uninitialized and an invalid
 * state.  It's desired to avoid both of those.  It is also not an Object, has no signals or
 * properties, doesn't work well with Gee, and is mutable.  This class attempts to solve these
 * issues.
 */

public class Date : Unit<Date>, Gee.Comparable<Date>, Gee.Hashable<Date> {
    public const string PROP_DAY_OF_WEEK = "day-of-week";
    public const string PROP_DAY_OF_MONTH = "day-of-month";
    public const string PROP_MONTH = "month";
    public const string PROP_YEAR = "year";
    
    /**
     * Options for {@link to_pretty_string}.
     */
    [Flags]
    public enum PrettyFlag {
        NONE = 0,
        /**
         * Indicates that the returned string should use date abbreviations wherever possible.
         */
        ABBREV,
        /**
         * Indicates that the year should be included in the return date string.
         */
        INCLUDE_YEAR,
        /**
         * Indicates that the localized string for "Today" should not be used if the date matches
         * {@link System.today}.
         */
        NO_TODAY,
        /**
         * Indicates the day of week should not be included.
         */
        NO_DAY_OF_WEEK
    }
    
    
    /**
     * @inheritDoc
     *
     * Overridden to prevent a reference cycle in {@link Span.start_date}.
     */
    public override Date start_date { get { return this; } }
    
    /**
     * @inheritDoc
     *
     * Overridden to prevent a reference cycle in {@link Span.end_date}.
     */
    public override Date end_date { get { return this; } }
    
    public DayOfWeek day_of_week { get; private set; }
    public DayOfMonth day_of_month { get; private set; }
    public Month month { get; private set; }
    public Year year { get; private set; }
    
    private GLib.Date gdate;
    
    /**
     * Creates a new {@link Date} object for the day, month, and year.
     *
     * @throws CalendarError if an invalid calendar day
     */
    public Date(DayOfMonth day_of_month, Month month, Year year) throws CalendarError {
        base.uninitialized(DateUnit.DAY);
        
        gdate.set_dmy(day_of_month.to_date_day(), month.to_date_month(), year.to_date_year());
        if (!gdate.valid()) {
            throw new CalendarError.INVALID("Invalid day/month/year %s/%s/%s", day_of_month.to_string(),
                month.to_string(), year.to_string());
        }
        
        day_of_week = DayOfWeek.from_gdate(gdate);
        this.day_of_month = day_of_month;
        this.month = month;
        this.year = year;
    }
    
    /**
     * Creates a {@link Date} for the {@link ExactTime}.
     */
    public Date.from_exact_time(ExactTime exact_time) {
        base.uninitialized(DateUnit.DAY);
        
        // Can use for_checked() methods because ExactTime can only be created with proper values
        day_of_month = exact_time.day_of_month;
        month = exact_time.month;
        year = exact_time.year;
        
        gdate.set_dmy(day_of_month.to_date_day(), month.to_date_month(), year.to_date_year());
        assert(gdate.valid());
        
        day_of_week = DayOfWeek.from_gdate(gdate);
    }
    
    /**
     * Creates a {@link Date} that corresponds to the current time in the specified {@link Timezone}.
     */
    public Date.now(Timezone tz) {
        this.from_exact_time(new ExactTime.now(tz));
    }
    
    internal Date.from_gdate(GLib.Date gdate) {
        base.uninitialized(DateUnit.DAY);
        
        assert(gdate.valid());
        
        this.gdate = gdate;
        
        day_of_week = DayOfWeek.from_gdate(gdate);
        day_of_month = DayOfMonth.from_gdate(gdate);
        month = Month.from_gdate(gdate);
        year = new Year.from_gdate(gdate);
    }
    
    /**
     * Returns the {@link Week} the {@link Date} falls in.
     */
    public Week week_of(FirstOfWeek first) {
        // calc how many days this Date is ahead of the first day of its week
        int ahead = day_of_week.ordinal(first) - first.as_day_of_week().ordinal(first);
        assert(ahead >= 0);
        
        Date start;
        if (ahead == 0) {
            start = this;
        } else {
            GLib.Date clone = gdate;
            clone.subtract_days(ahead);
            start = new Date.from_gdate(clone);
        }
        
        // add six days and that's the last day of the week
        Date end = start.adjust_by(DayOfWeek.COUNT - 1, DateUnit.DAY);
        
        // get the numeric week of the year of this date
        int week_of_year;
        switch (first) {
            case FirstOfWeek.MONDAY:
                week_of_year = (int) gdate.get_monday_week_of_year();
            break;
            
            case FirstOfWeek.SUNDAY:
                week_of_year = (int) gdate.get_sunday_week_of_year();
            break;
            
            default:
                assert_not_reached();
        }
        
        // get the numeric week of the month of this date (using weeks of the year to calculate)
        GLib.Date first_of_month = GLib.Date();
        first_of_month.set_dmy(1, month.to_date_month(), year.to_date_year());
        assert(first_of_month.valid());
        
        int week_of_month;
        switch (first) {
            case FirstOfWeek.MONDAY:
                week_of_month = week_of_year - ((int) first_of_month.get_monday_week_of_year()) + 1;
            break;
            
            case FirstOfWeek.SUNDAY:
                week_of_month = week_of_year - ((int) first_of_month.get_sunday_week_of_year()) + 1;
            break;
            
            default:
                assert_not_reached();
        }
        
        return new Week(start, end, week_of_month, week_of_year, month_of_year(), first);
    }
    
    /**
     * Returns the {@link MonthOfYear} the {@link Date} falls in.
     */
    public MonthOfYear month_of_year() {
        return new MonthOfYear(month, year);
    }
    
    /**
     * @inheritDoc
     */
    public override Date adjust(int quantity) {
        return adjust_by(quantity, DateUnit.DAY);
    }
    
    /**
     * Returns a new {@link Date} adjusted from this Date by the specifed quantity of time.
     *
     * Subtraction (adjusting to a past date) is acheived by using a negative quantity.
     */
    public Date adjust_by(int quantity, DateUnit unit) {
        if (quantity == 0)
            return this;
        
        GLib.Date clone = gdate;
        switch (unit) {
            case DateUnit.DAY:
                if (quantity > 0)
                    clone.add_days(quantity);
                else
                    clone.subtract_days(-quantity);
            break;
            
            case DateUnit.WEEK:
                if (quantity > 0)
                    clone.add_days(quantity * DayOfWeek.COUNT);
                else
                    clone.subtract_days((-quantity) * DayOfWeek.COUNT);
            break;
            
            case DateUnit.MONTH:
                if (quantity > 0)
                    clone.add_months(quantity);
                else
                    clone.subtract_months(-quantity);
            break;
            
            case DateUnit.YEAR:
                if (quantity > 0)
                    clone.add_years(quantity);
                else
                    clone.subtract_years(-quantity);
            break;
            
            default:
                assert_not_reached();
        }
        
        return new Date.from_gdate(clone);
    }
    
    /**
     * Returns the {@link Date} of the upcoming (next chronological) {@link DayOfWeek}.
     *
     * Set {@link includes_this_day} to true if this Date is to be considered "upcoming", that is,
     * if it falls on the day of the week, it is returned.
     *
     * @see prior
     */
    public Date upcoming(DayOfWeek dow, bool includes_this_day) {
        return upcoming_prior(dow, includes_this_day, 1);
    }
    
    /**
     * Returns the {@link Date} of the prior (previous chronological) {@link DayOfWeek}.
     *
     * Set {@link includes_this_day} to true if this Date is to be considered "prior", that is,
     * if it falls on the day of the week, it is returned.
     *
     * @see upcoming
     */
    public Date prior(DayOfWeek dow, bool includes_this_day) {
        return upcoming_prior(dow, includes_this_day, -1);
    }
    
    private Date upcoming_prior(DayOfWeek dow, bool includes_this_day, int adjustment) {
        // look for current date being the one
        if (day_of_week.equal_to(dow) && includes_this_day)
            return this;
        
        // find a Date for day of the week ... brute force isn't great, but it works
        Date upcoming_prior = this;
        for (;;) {
            upcoming_prior = upcoming_prior.adjust(adjustment);
            if (upcoming_prior.day_of_week.equal_to(dow))
                return upcoming_prior;
        }
    }
    
    /**
     * @inheritDoc
     */
    public override int difference(Date other) {
        return (this != other) ? gdate.days_between(other.gdate) : 0;
    }
    
    /**
     * Returns a {@link Date} clamped between the two supplied Dates, inclusive.
     */
    public Date clamp(Date min, Date max) {
        GLib.Date clone = gdate;
        clone.clamp(min.gdate, max.gdate);
        
        return new Date.from_gdate(clone);
    }
    
    public int compare_to(Date other) {
        return (this != other) ? gdate.compare(other.gdate) : 0;
    }
    
    public bool equal_to(Date other) {
        return compare_to(other) == 0;
    }
    
    public uint hash() {
        return gdate.get_julian();
    }
    
    public string format(string fmt) {
        // TODO: This isn't a guaranteed way to allocate space, but without parsing fmt (and
        // accounting for locale-specific string lengths), I'm not sure of a better way
        char[] buf = new char[256];
        gdate.strftime(buf, fmt);
        
        return (string) buf;
    }
    
    /**
     * Returns the {@link Date} in a localized standardized format, i.e. "08/23/01"
     */
    public string to_standard_string() {
        return format(FMT_FULL_DATE);
    }
    
    /**
     * Returns the {@link Date} in a prettified, localized format according to supplied
     * {@link PrettyFlag}s.
     *
     * Returns "Today" (localized) if this matches {@link System.today} unless the NO_TODAY flag
     * or INCLUDE_YEAR flag is specified.
     */
    public string to_pretty_string(PrettyFlag flags) {
        bool abbrev = (flags & PrettyFlag.ABBREV) != 0;
        bool with_year = (flags & PrettyFlag.INCLUDE_YEAR) != 0;
        bool no_today = (flags & PrettyFlag.NO_TODAY) != 0;
        bool no_dow = (flags & PrettyFlag.NO_DAY_OF_WEEK) != 0;
        
        if (!no_today && !with_year && equal_to(System.today))
            return _("Today");
        
        unowned string fmt;
        if (abbrev) {
            if (no_dow)
                fmt = with_year ? FMT_PRETTY_DATE_ABBREV_NO_DOW : FMT_PRETTY_DATE_ABBREV_NO_DOW_NO_YEAR;
            else
                fmt = with_year ? FMT_PRETTY_DATE_ABBREV : FMT_PRETTY_DATE_ABBREV_NO_YEAR;
        } else {
            if (no_dow)
                fmt = with_year ? FMT_PRETTY_DATE_NO_DOW : FMT_PRETTY_DATE_NO_DOW_NO_YEAR;
            else
                fmt = with_year ? FMT_PRETTY_DATE : FMT_PRETTY_DATE_NO_YEAR;
        }
        
        return String.reduce_whitespace(format(fmt));
    }
    
    public override string to_string() {
        return format("%x");
    }
}

}

