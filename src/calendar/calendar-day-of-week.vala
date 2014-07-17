/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable one-based representation of a day of a week (Monday, Tuesday, etc.).
 *
 * Neither Monday nor Sunday are hard-defined as the first day of the week.  Accessing these
 * objects via for() requires the caller to specify which is their definition of the first weekday.
 */

public class DayOfWeek : BaseObject, Gee.Hashable<DayOfWeek> {
    private class DayOfWeekIterator : BaseObject, Collection.SimpleIterator<DayOfWeek> {
        private DayOfWeek current;
        private int count = -1;
        
        public DayOfWeekIterator(FirstOfWeek first_of_week) {
            current = first_of_week.as_day_of_week();
        }
        
        public bool next() {
            // because iterators are "off-track", next() is called first, so watch for that
            if (count == -1) {
                count = 0;
                
                return true;
            }
            
            current = current.next();
            
            return (++count < COUNT);
        }
        
        public new DayOfWeek get() {
            return current;
        }
        
        public override string to_string() {
            return "DayOfWeekIterator";
        }
    }
    
    public static DayOfWeek MON;
    public static DayOfWeek TUE;
    public static DayOfWeek WED;
    public static DayOfWeek THU;
    public static DayOfWeek FRI;
    public static DayOfWeek SAT;
    public static DayOfWeek SUN;
    
    public static DayOfWeek[] weekdays;
    public static DayOfWeek[] weekend_days;
    
    public const int MIN = 1;
    public const int MAX = 7;
    public const int COUNT = MAX - MIN + 1;
    
    private static DayOfWeek[]? days_of_week_monday = null;
    private static DayOfWeek[]? days_of_week_sunday = null;
    
    private static Gee.Map<string, DayOfWeek> parse_map;
    
    /**
     * The abbreviated locale-specific name for the day of the week.
     */
    public string abbrev_name { get; private set; }
    
    /**
     * The full locale-specific name for the day of the week.
     */
    public string full_name { get; private set; }
    
    // 1-based ordinals
    private int value_monday;
    private int value_sunday;
    
    private DayOfWeek(int value, string abbrev_name, string full_name) {
        assert(value >= MIN && value <= MAX);
        
        // internally, Monday is default the first day of the week
        value_monday = value;
        value_sunday = (value % COUNT) + 1;
        this.abbrev_name = abbrev_name;
        this.full_name = full_name;
    }
    
    internal static void init() {
        // Because ctime won't cough up the strings easily, get them out by walking a full week
        // of days (doesn't matter where we start, as long as they're valid days) and stash the
        // locale-specific strings to pass to the constructor
        GLib.Date date = GLib.Date();
        date.set_dmy(1, 1, 2014);
        
        // GLib.Weekday is 1-based, Monday first, so these arrays are the same
        string[] abbrevs = new string[COUNT];
        string[] fulls = new string[COUNT];
        char[] buf = new char[64];
        for (int ctr = MIN; ctr <= MAX; ctr++) {
            assert(date.valid());
            
            // GLib.Weekday is 1-based, Monday first
            int offset = (int) date.get_weekday() - 1;
            assert(offset >= 0 && offset < COUNT);
            
            date.strftime(buf, FMT_DAY_OF_WEEK_ABBREV);
            abbrevs[offset] = (string) buf;
            
            date.strftime(buf, FMT_DAY_OF_WEEK_FULL);
            fulls[offset] = (string) buf;
            
            date.add_days(1);
        }
        
        parse_map = new Gee.HashMap<string, DayOfWeek>(String.ci_hash, String.ci_equal);
        
        // Following GLib's lead, days of week Monday-first is straightforward
        days_of_week_monday = new DayOfWeek[COUNT];
        for (int ctr = MIN; ctr <= MAX; ctr++) {
            DayOfWeek dow = new DayOfWeek(ctr, abbrevs[ctr - MIN], fulls[ctr - MIN]);
            days_of_week_monday[ctr - MIN] = dow;
            
            // add to parse map by abbreivated and full name
            parse_map.set(dow.abbrev_name, dow);
            parse_map.set(dow.full_name, dow);
        }
        
        MON = days_of_week_monday[0];
        TUE = days_of_week_monday[1];
        WED = days_of_week_monday[2];
        THU = days_of_week_monday[3];
        FRI = days_of_week_monday[4];
        SAT = days_of_week_monday[5];
        SUN = days_of_week_monday[6];
        
        // now fill in the Sunday-first array using the already-built objects
        days_of_week_sunday = new DayOfWeek[COUNT];
        days_of_week_sunday[0] = SUN;
        days_of_week_sunday[1] = MON;
        days_of_week_sunday[2] = TUE;
        days_of_week_sunday[3] = WED;
        days_of_week_sunday[4] = THU;
        days_of_week_sunday[5] = FRI;
        days_of_week_sunday[6] = SAT;
        
        weekdays = new DayOfWeek[5];
        weekdays[0] = MON;
        weekdays[1] = TUE;
        weekdays[2] = WED;
        weekdays[3] = THU;
        weekdays[4] = FRI;
        
        weekend_days = new DayOfWeek[2];
        weekend_days[0] = SAT;
        weekend_days[1] = SUN;
    }
    
    internal static void terminate() {
        days_of_week_monday = days_of_week_sunday = null;
        MON = TUE = WED = THU = FRI = SAT = SUN = null;
        weekdays = weekend_days = null;
    }
    
    /**
     * Returns the day of the week for the specified one-based value.
     */
    public static DayOfWeek for(int value, FirstOfWeek first_of_week) throws CalendarError {
        int index = value - MIN;
        
        if (index < 0 || index >= COUNT)
            throw new CalendarError.INVALID("Invalid day of week value %d", value);
        
        return all(first_of_week)[index];
    }
    
    /**
     * Should only be used by internal calls when value is known to be safe and doesn't originate
     * from external sources, like a file, network, or user-input.
     */
    internal static DayOfWeek for_checked(int value, FirstOfWeek first_of_week) {
        try {
            return for(value, first_of_week);
        } catch (CalendarError calerr) {
            error("%s", calerr.message);
        }
    }
    
    /**
     * Return all {@link DayOfWeeks} ordered by the {@link FirstOfWeek}.
     */
    public static unowned DayOfWeek[] all(FirstOfWeek first_of_week) {
        switch (first_of_week) {
            case FirstOfWeek.MONDAY:
                return days_of_week_monday;
            
            case FirstOfWeek.SUNDAY:
                return days_of_week_sunday;
            
            default:
                assert_not_reached();
        }
    }
    
    internal static DayOfWeek from_gdate(GLib.Date date) {
        assert(date.valid());
        
        // GLib.Weekday is Monday-first
        return for_checked(date.get_weekday(), FirstOfWeek.MONDAY);
    }
    
    /**
     * Parses the string looking for a match with any of the {@link DayOfWeek}'s {@link abbrev_name}
     * or {@link full_name}.
     *
     * parse() is case-insensitive.
     */
    public static DayOfWeek? parse(string str) {
        return parse_map.get(str);
    }
    
    /**
     * The one-based ordinal value of the day of the week, depended on what the definition of
     * the first day of the week.
     */
    public int ordinal(FirstOfWeek first_of_week) {
        switch (first_of_week) {
            case FirstOfWeek.MONDAY:
                return value_monday;
            
            case FirstOfWeek.SUNDAY:
                return value_sunday;
            
            default:
                assert_not_reached();
        }
    }
    
    /**
     * Returns the next {@link DayOfWeek}.
     *
     * This method will loop, hence it never returns null or another terminating indicator.
     *
     * @see prev
     */
    public DayOfWeek next() {
        // first day of week doesn't matter for this operation, so use Monday
        int next_value = value_monday + 1;
        if (next_value > MAX)
            next_value = MIN;
        
        return for_checked(next_value, FirstOfWeek.MONDAY);
    }
    
    /**
     * Returns the previous {@link DayOfWeek}.
     *
     * This method will loop, hence it never returns null or another terminating indicator.
     *
     * @see next
     */
    public DayOfWeek previous() {
        // first day of week doesn't matter for this operation, so use Monday
        int previous_value = value_monday - 1;
        if (previous_value < MIN)
            previous_value = MAX;
        
        return for_checked(previous_value, FirstOfWeek.MONDAY);
    }
    
    /**
     * Returns an Iterator for every day of the week, starting at {@link FirstOfWeek}.
     */
    public static Collection.SimpleIterator<DayOfWeek> iterator(FirstOfWeek first_of_week) {
        return new DayOfWeekIterator(first_of_week);
    }
    
    public bool equal_to(DayOfWeek other) {
        return this == other;
    }
    
    public uint hash() {
        return direct_hash(this);
    }
    
    public override string to_string() {
        return full_name;
    }
}

}

