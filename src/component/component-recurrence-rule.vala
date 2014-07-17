/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Component {

/**
 * A mutable convenience representation of an iCalendar recurrence rule (RRULE).
 *
 * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]]
 * and [[https://tools.ietf.org/html/rfc5545#section-3.8.5.3]]
 */

public class RecurrenceRule : BaseObject {
    public const string PROP_FREQ = "freq";
    public const string PROP_UNTIL = "until";
    public const string PROP_COUNT = "count";
    public const string PROP_INTERVAL = "interval";
    public const string PROP_FIRST_OF_WEEK = "first-of-week";
    
    /**
     * Enumeration of various BY rules (BYSECOND, BYMINUTE, etc.)
     */
    public enum ByRule {
        SECOND = 0,
        MINUTE,
        HOUR,
        DAY,
        MONTH_DAY,
        YEAR_DAY,
        WEEK_NUM,
        MONTH,
        SET_POS,
        /**
         * The number of {@link ByRule}s, this is not a valid value.
         */
        COUNT;
    }
    
    /**
     * Frequency.
     *
     * This is the only required field in an RRULE.
     */
    public iCal.icalrecurrencetype_frequency freq { get; set; }
    
    /**
     * Returns true if {@link freq} is iCal.icalrecurrencetype_frequence.DAILY_RECURRENCE,
     */
    public bool is_daily { get { return freq == iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE; } }
    
    /**
     * Returns true if {@link freq} is iCal.icalrecurrencetype_frequence.DAILY_RECURRENCE,
     */
    public bool is_weekly { get { return freq == iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE; } }
    
    /**
     * Returns true if {@link freq} is iCal.icalrecurrencetype_frequence.MONTHLY_RECURRENCE,
     */
    public bool is_monthly { get { return freq == iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE; } }
    
    /**
     * Returns true if {@link freq} is iCal.icalrecurrencetype_frequence.YEARLY_RECURRENCE,
     */
    public bool is_yearly { get { return freq == iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE; } }
    
    /**
     * Until (end date), inclusive.
     *
     * This is mutually exclusive with {@link count} and {@link until_exact_time}.
     *
     * @see set_until_date
     */
    public Calendar.Date? until_date { get; private set; default = null; }
    
    /**
     * Until (end date/time).
     *
     * This is mutually exclusive with {@link count} and {@link until_date}.
     *
     * @see set_until_exact_time
     */
    public Calendar.ExactTime? until_exact_time { get; private set; default = null; }
    
    /**
     * Total number of recurrences.
     *
     * Zero indicates "not set", not zero recurrences.
     *
     * This is mutually exclusive with {@link until_date} and {@link until_exact_time}.
     *
     * @see set_recurrence_count
     */
    public int count { get; private set; default = 0; }
    
    /**
     * Returns true if the recurrence rule has a duration.
     *
     * @see until
     * @see count
     */
    public bool has_duration { get { return until_date != null || until_exact_time != null || count > 0; } }
    
    /**
     * Interval between recurrences.
     *
     * A positive integer representing the interval (duration between) of each recurrence.  The
     * actual amount of time elapsed is determined by the {@link frequency} property.
     *
     * interval may be any value from 1 to short.MAX.
     */
    private int _interval = 1;
    public int interval {
        get { return _interval; }
        set { _interval = value.clamp(1, short.MAX); }
    }
    
    /**
     * Start of work week (WKST).
     */
    public Calendar.DayOfWeek? first_of_week { get; set; default = null; }
    
    private Gee.SortedSet<int> by_second = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_minute = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_hour = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_day = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_month_day = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_year_day = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_week_num = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_month = new Gee.TreeSet<int>();
    private Gee.SortedSet<int> by_set_pos = new Gee.TreeSet<int>();
    
    /**
     * Fired when a BY rule is updated (BYSECOND, BYMINUTE, etc.)
     */
    public signal void by_rule_updated(ByRule by_rule);
    
    public RecurrenceRule(iCal.icalrecurrencetype_frequency freq) {
        this.freq = freq;
    }
    
    internal RecurrenceRule.from_ical(iCal.icalcomponent ical_component, bool strict) throws Error {
        // need DTSTART for timezone purposes
        DateTime dtstart = new DateTime(ical_component, iCal.icalproperty_kind.DTSTART_PROPERTY);
        
        // fetch the RRULE from the component
        unowned iCal.icalproperty? rrule_property = ical_component.get_first_property(
            iCal.icalproperty_kind.RRULE_PROPERTY);
        if (rrule_property == null)
            throw new ComponentError.UNAVAILABLE("No RRULE found in component");
        
        iCal.icalrecurrencetype rrule = rrule_property.get_rrule();
        
        freq = rrule.freq;
        interval = rrule.interval;
        
        if (rrule.count > 0) {
            set_recurrence_count(rrule.count);
        } else {
            try {
                Component.DateTime date_time = new DateTime.rrule_until(rrule, dtstart, strict);
                if (date_time.is_date)
                    set_recurrence_end_date(date_time.to_date());
                else
                    set_recurrence_end_exact_time(date_time.to_exact_time());
            } catch (ComponentError comperr) {
                if (!(comperr is ComponentError.UNAVAILABLE))
                    throw comperr;
            }
        }
        
        switch (rrule.week_start) {
            case iCal.icalrecurrencetype_weekday.SUNDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.SUN;
            break;
            
            case iCal.icalrecurrencetype_weekday.MONDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.MON;
            break;
            
            case iCal.icalrecurrencetype_weekday.TUESDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.TUE;
            break;
            
            case iCal.icalrecurrencetype_weekday.WEDNESDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.WED;
            break;
            
            case iCal.icalrecurrencetype_weekday.THURSDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.THU;
            break;
            
            case iCal.icalrecurrencetype_weekday.FRIDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.FRI;
            break;
            
            case iCal.icalrecurrencetype_weekday.SATURDAY_WEEKDAY:
                first_of_week = Calendar.DayOfWeek.SAT;
            break;
            
            case iCal.icalrecurrencetype_weekday.NO_WEEKDAY:
            default:
                first_of_week = null;
            break;
        }
        
        fill_by(rrule.by_second, by_second);
        fill_by(rrule.by_minute, by_minute);
        fill_by(rrule.by_hour, by_hour);
        fill_by(rrule.by_day, by_day);
        fill_by(rrule.by_month_day, by_month_day);
        fill_by(rrule.by_year_day, by_year_day);
        fill_by(rrule.by_week_no, by_week_num);
        fill_by(rrule.by_month, by_month);
        fill_by(rrule.by_set_pos, by_set_pos);
    }
    
    private void fill_by(short[] ical_by_ar, Gee.SortedSet<int> by_set) {
        for (int ctr = 0; ctr < ical_by_ar.length; ctr++) {
            short by = ical_by_ar[ctr];
            if (by == iCal.RECURRENCE_ARRAY_MAX)
                break;
            
            by_set.add(by);
        }
    }
    
    /**
     * Sets the {@link until_date} property.
     *
     * Also sets {@link count} to zero and nulls out {@link until_exact_time}.
     *
     * Passing null will clear all these properties.
     */
    public void set_recurrence_end_date(Calendar.Date? date) {
        freeze_notify();
        
        until_date = date;
        until_exact_time = null;
        count = 0;
        
        thaw_notify();
    }
    
    /**
     * Sets the {@link until_exact_time} property.
     *
     * Also sets {@link count} to zero and nulls out {@link until_date}.
     *
     * Passing null will clear all these properties.
     */
    public void set_recurrence_end_exact_time(Calendar.ExactTime? exact_time) {
        freeze_notify();
        
        until_date = null;
        until_exact_time = exact_time;
        count = 0;
        
        thaw_notify();
    }
    
    /**
     * Returns the UNTIL property as a {@link Calendar.Date}.
     *
     * If {@link until_exact_time} is set, only the Date portion is returned.
     *
     * @returns null if neither {@link until_date} or until_exact_time is set.
     */
    public Calendar.Date? get_recurrence_end_date() {
        if (until_date != null)
            return until_date;
        
        if (until_exact_time != null)
            return new Calendar.Date.from_exact_time(until_exact_time);
        
        return null;
    }
    
    /**
     * Sets the {@link count} property.
     *
     * Also clears {@link until_date} and {@link until_exact_time}.
     *
     * Passing zero will clear all these properties.
     */
    public void set_recurrence_count(int count) {
        freeze_notify();
        
        until_date = null;
        until_exact_time = null;
        this.count = count.clamp(0, int.MAX);
        
        thaw_notify();
    }
    
    /**
     * Encode a {@link Calendar.DayOfWeek} and its position (i.e. second Thursday of the month,
     * last Wednesday of the year) into a value for {@link set_by_rule} when using
     * {@link ByRule.DAY}.
     *
     * For position, 1 = first, 2 = second, -1 = last, -2 = second to last, etc.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]] for information how these values
     * operate according to this RRULE's {@link freq}.
     *
     * Use null for DayOfWeek and zero for position to mean "any" or "every".
     *
     * @see encode_days
     * @see decode_day
     */
    public static int encode_day(Calendar.DayOfWeek? dow, int position) {
        // these encodings are mapped to iCal.icalrecurrencetype_weekday, which is SUNDAY-based
        int dow_value = (dow != null) ? dow.ordinal(Calendar.FirstOfWeek.SUNDAY) : 0;
        
        position = position.clamp(short.MIN, short.MAX);
        int value = (position * 8) + (position >= 0 ? dow_value : 0 - dow_value);
        
        return value;
    }
    
    /**
     * Decode the integer returned by {@link get_by_rule} when {@link ByRule.DAY} passed in.
     *
     * If null is returned for DayOfWeek or zero for position, that indicates "any" or "every".
     * See {@link encode_day} for more information.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]] for information how these values
     * operate according to this RRULE's {@link freq}.
     *
     * Returns false if the supplied value is definitely not encoded correctly.
     */
    public static bool decode_day(int value, out Calendar.DayOfWeek? dow, out int position) {
        position = iCal.icalrecurrencetype.day_position((short) value);
        
        dow = null;
        int dow_value = (int) iCal.icalrecurrencetype.day_day_of_week((short) value);
        if (dow_value != 0) {
            try {
                // iCal.icalrecurrencetype_weekday is SUNDAY-based
                dow = Calendar.DayOfWeek.for(dow_value, Calendar.FirstOfWeek.SUNDAY);
            } catch (CalendarError calerr) {
                debug("Unable to decode day of week value %d: %s", dow_value, calerr.message);
                
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Encode a Gee.Map of {@link Calendar.DayOfWeek} and its position into a value for
     * {@link set_by_rule} when using {@link ByRule.DAY}.
     *
     * Use null for DayOfWeek and zero for position to mean "any" or "every".
     *
     * @see encode_day
     */
    public static Gee.Collection<int> encode_days(Gee.Map<Calendar.DayOfWeek?, int>? day_values) {
        if (day_values == null || day_values.size == 0)
            return Gee.Collection.empty<int>();
        
        Gee.Collection<int> encoded = new Gee.ArrayList<int>();
        Gee.MapIterator<Calendar.DayOfWeek?, int> iter = day_values.map_iterator();
        while (iter.next())
            encoded.add(encode_day(iter.get_key(), iter.get_value()));
        
        return encoded;
    }
    
    /**
     * Decode a Gee.Collection of encoded {@link ByRule.DAY} values into their positions and
     * {@link Calendar.DayOfWeek}.
     *
     * Invalid values are skipped.
     *
     * @see encode_day
     * @see encode_days
     * @see decode_day
     */
    public static Gee.Map<Calendar.DayOfWeek?, int> decode_days(Gee.Collection<int>? values) {
        if (values == null || values.size == 0)
            return Gee.Map.empty<Calendar.DayOfWeek?, int>();
        
        Gee.Map<Calendar.DayOfWeek?, int> decoded = new Gee.HashMap<Calendar.DayOfWeek?, int>();
        foreach (int value in values) {
            Calendar.DayOfWeek? dow;
            int position;
            if (decode_day(value, out dow, out position))
                decoded.set(dow, position);
        }
        
        return decoded;
    }
    
    private Gee.SortedSet<int> get_by_set(ByRule by_rule) {
        switch (by_rule) {
            case ByRule.SECOND:
                return by_second;
            
            case ByRule.MINUTE:
                return by_minute;
            
            case ByRule.HOUR:
                return by_hour;
            
            case ByRule.DAY:
                return by_day;
            
            case ByRule.MONTH_DAY:
                return by_month_day;
            
            case ByRule.YEAR_DAY:
                return by_year_day;
            
            case ByRule.WEEK_NUM:
                return by_week_num;
            
            case ByRule.MONTH:
                return by_month;
            
            case ByRule.SET_POS:
                return by_set_pos;
            
            default:
                assert_not_reached();
        }
    }
    
    /**
     * Returns a read-only sorted set of BY rule settings for the specified {@link ByRule}.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]] for information how these values
     * operate according to their associated ByRule and this RRULE's {@link freq}.
     */
    public Gee.SortedSet<int> get_by_rule(ByRule by_rule) {
        return get_by_set(by_rule).read_only_view;
    }
    
    private bool is_int_short(int value) {
        return value >= short.MIN && value <= short.MAX;
    }
    
    /**
     * Replaces the existing set of values for the BY rules with the supplied values.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]] for information how these values
     * operate according to their associated ByRule and this RRULE's {@link freq}.
     *
     * Pass null or an empty Collection to clear the by-rules values.
     *
     * Any value greater than short.MAX or less than short.MIN will be dropped.
     *
     * Use {@link encode_days} when passing values for {@link ByRule.DAY}.
     *
     * @see add_by_rule
     * @see by_rule_updated
     */
    public void set_by_rule(ByRule by_rule, Gee.Collection<int>? values) {
        Gee.SortedSet<int> by_set = get_by_set(by_rule);
        
        by_set.clear();
        if (values != null && values.size > 0)
            by_set.add_all(traverse<int>(values).filter(is_int_short).to_array_list());
        
        by_rule_updated(by_rule);
    }
    
    /**
     * Adds the supplied values to the existing set of values for the BY rules.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.3.10]] for information how these values
     * operate according to their associated ByRule and this RRULE's {@link freq}.
     *
     * Null or an empty Collection is a no-op.
     *
     * Any value greater than short.MAX or less than short.MIN will be dropped.
     *
     * Use {@link encode_days} when passing values for {@link ByRule.DAY}.
     *
     * @see set_by_rule
     * @see by_rule_updated
     */
    public void add_by_rule(ByRule by_rule, Gee.Collection<int>? values) {
        Gee.SortedSet<int> by_set = get_by_set(by_rule);
        
        if (values != null && values.size > 0)
            by_set.add_all(traverse<int>(values).filter(is_int_short).to_array_list());
        
        by_rule_updated(by_rule);
    }
    
    /**
     * Returns a Gee.Set of {@link ByRule}s that are active, i.e. have defined rules.
     */
    public Gee.Set<ByRule> get_active_by_rules() {
        Gee.Set<ByRule> active = new Gee.HashSet<ByRule>();
        for (int ctr = 0; ctr < ByRule.COUNT; ctr++) {
            ByRule by_rule = (ByRule) ctr;
            
            if (get_by_set(by_rule).size > 0)
                active.add(by_rule);
        }
        
        return active;
    }
    
    /**
     * Converts a {@link RecurrenceRule} into an iCalendar RRULE property and adds it to the
     * iCal component.
     *
     * This call makes no attempt to remove an existing RRULE property; that should be performed by
     * the caller first.
     */
    internal void add_to_ical(iCal.icalcomponent ical_component) {
        iCal.icalrecurrencetype rrule = { 0 };
        
        rrule.freq = freq;
        
        if (until_date != null)
            date_to_ical(until_date, &rrule.until);
        else if (until_exact_time != null)
            exact_time_to_ical(until_exact_time, &rrule.until);
        else if (count > 0)
            rrule.count = count;
        
        rrule.interval = (short) interval;
        
        if (first_of_week == null)
            rrule.week_start = iCal.icalrecurrencetype_weekday.NO_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.SUN)
            rrule.week_start = iCal.icalrecurrencetype_weekday.SUNDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.MON)
            rrule.week_start = iCal.icalrecurrencetype_weekday.MONDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.TUE)
            rrule.week_start = iCal.icalrecurrencetype_weekday.TUESDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.WED)
            rrule.week_start = iCal.icalrecurrencetype_weekday.WEDNESDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.THU)
            rrule.week_start = iCal.icalrecurrencetype_weekday.THURSDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.FRI)
            rrule.week_start = iCal.icalrecurrencetype_weekday.FRIDAY_WEEKDAY;
        else if (first_of_week == Calendar.DayOfWeek.SAT)
            rrule.week_start = iCal.icalrecurrencetype_weekday.SATURDAY_WEEKDAY;
        else
            assert_not_reached();
        
        fill_ical_by(by_second, &rrule.by_second[0], rrule.by_second.length);
        fill_ical_by(by_minute, &rrule.by_minute[0], rrule.by_minute.length);
        fill_ical_by(by_hour, &rrule.by_hour[0], rrule.by_hour.length);
        fill_ical_by(by_day, &rrule.by_day[0], rrule.by_day.length);
        fill_ical_by(by_month_day, &rrule.by_month_day[0], rrule.by_month_day.length);
        fill_ical_by(by_year_day, &rrule.by_year_day[0], rrule.by_year_day.length);
        fill_ical_by(by_week_num, &rrule.by_week_no[0], rrule.by_week_no.length);
        fill_ical_by(by_month, &rrule.by_month[0], rrule.by_month.length);
        fill_ical_by(by_set_pos, &rrule.by_set_pos[0], rrule.by_set_pos.length);
        
        iCal.icalproperty rrule_property = new iCal.icalproperty(iCal.icalproperty_kind.RRULE_PROPERTY);
        rrule_property.set_rrule(rrule);
        
        ical_component.add_property(rrule_property);
    }
    
    private void fill_ical_by(Gee.SortedSet<int> by_set, short *ical_by_ar, int ar_length) {
        int index = 0;
        foreach (int by in by_set) {
            ical_by_ar[index++] = (short) by;
            
            // watch for overflow
            if (index >= ar_length)
                break;
        }
        
        if (index < ar_length)
            ical_by_ar[index] = (short) iCal.RECURRENCE_ARRAY_MAX;
    }
    
    public override string to_string() {
        return "RRULE %s".printf(freq.to_string());
    }
}

}

