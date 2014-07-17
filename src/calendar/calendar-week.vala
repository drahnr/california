/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable representation of a calendar week, meaning the {@link start_date} is the first
 * day of the week (as defined by {@link FirstOfWeek} and the {@link end_date) is six days after
 * that.
 *
 * As a {@link DateSpan}, it's possible for the start and end date to "bleed" into other months and
 * years.
 *
 * Due to the rigid definition of a Week, they cannot be created off-the-cuff.  Use
 * {@link Date.week_of} to obtain a Week for a particular calendar day.
 */

public class Week : Unit<Week>, Gee.Comparable<Week>, Gee.Hashable<Week> {
    public const int MIN_WEEK_OF_MONTH = 1;
    public const int MAX_WEEK_OF_MONTH = 6;
    
    /**
     * The one-based week of the month (1 to 6).
     */
    public int week_of_month { get; private set; }
    
    /**
     * The one-based week of the year (1 to 52).
     *
     * If the start of the week is before the first day of {@link month_of_year}, this value will
     * be zero.
     *
     */
    public int week_of_year { get; private set; }
    
    /**
     * The {@link Month} of the {@link Year} the week falls in.
     *
     * It's possible days within this week fall outside this Month or even this Year.  This Month
     * and Year is what {@link week_of_the_month} and {@link week_of_the_year} refer to.
     */
    public MonthOfYear month_of_year { get; private set; }
    
    /**
     * How this object defines the first day of the week.
     */
    public FirstOfWeek first_of_week { get; private set; }
    
    /**
     * Important: Week does not validate that start and end are in fact the start and end of the
     * calendar week.
     */
    internal Week(Date start, Date end, int week_of_month, int week_of_year, MonthOfYear month_of_year,
        FirstOfWeek first_of_week) {
        base (DateUnit.WEEK, start, end);
        
        this.week_of_month = week_of_month;
        this.week_of_year = week_of_year;
        this.month_of_year = month_of_year;
        this.first_of_week = first_of_week;
    }
    
    /**
     * Returns the {@link Date} for the {@link DayOfWeek}.
     */
    public Date date_at(DayOfWeek dow) {
        // although mixing FirstOfWeek is dangerous, don't trust simple math here because of this issue
        foreach (Date date in to_date_span()) {
            if (date.day_of_week.equal_to(dow))
                return date;
        }
        
        assert_not_reached();
    }
    
    /**
     * @inheritDoc
     */
    public override Week adjust(int quantity) {
        return start_date.adjust_by(quantity, DateUnit.WEEK).week_of(first_of_week);
    }
    
    /**
     * @inheritDoc
     */
    public override int difference(Week other) {
        int compare = compare_to(other);
        if (compare == 0)
            return 0;
        
        // TODO: Iterating sucks, but it will have to suffice for now.
        int count = 0;
        Week current = this;
        for (;;) {
            current = (compare > 0) ? current.previous() : current.next();
            count += (compare > 0) ? -1 : 1;
            
            if (current.equal_to(other))
                return count;
        }
    }
    
    public int compare_to(Week other) {
        return (this != other) ? start_date.compare_to(other.start_date) : 0;
    }
    
    public bool equal_to(Week other) {
        return compare_to(other) == 0;
    }
    
    public uint hash() {
        // 6 bits for week of year (1 - 52)
        return (month_of_year.hash() << 6) | week_of_year;
    }
    
    public override string to_string() {
        return "week %d of %s (%s)".printf(week_of_year, month_of_year.to_string(), to_date_span().to_string());
    }
}

}

