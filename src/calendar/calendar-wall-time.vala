/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable represenation of "wall clock time", that is, an hour, minute, and seconds with no
 * correspondence to a day of a year.
 */

public class WallTime : BaseObject, Gee.Comparable<WallTime>, Gee.Hashable<WallTime> {
    /**
     * Options for {@link to_pretty_string}.
     */
    [Flags]
    public enum PrettyFlag {
        NONE = 0,
        /**
         * Indicates that the {@link seconds} property should be included in the string.
         *
         * @see OPTIONAL_MINUTES
         */
        INCLUDE_SECONDS,
        /**
         * Include minutes only if the time is not on the hour.
         *
         * If minutes are not displayed, seconds will not be either.
         */
        OPTIONAL_MINUTES,
        /**
         * Only show meridiem indicator if post-meridiem.
         *
         * Ignored if displaying 24-hour time.
         */
        MERIDIEM_POST_ONLY,
        /**
         * Use brief meridiem indicators.
         */
        BRIEF_MERIDIEM
    }
    
    public const int HOURS_PER_DAY = 24;
    public const int MIN_HOUR = 0;
    public const int MAX_HOUR = HOURS_PER_DAY - 1;
    
    public const int MINUTES_PER_HOUR = 60;
    public const int MIN_MINUTE = 0;
    public const int MAX_MINUTE = MINUTES_PER_HOUR - 1;
    
    public const int SECONDS_PER_MINUTE = 60;
    public const int MIN_SECOND = 0;
    public const int MAX_SECOND = SECONDS_PER_MINUTE - 1;
    
    /**
     * Earliest {@link WallTime} available.
     */
    public static WallTime earliest { get; private set; }
    
    /**
     * Latest {@link WallTime} available.
     */
    public static WallTime latest { get; private set; }
    
    /**
     * Zero-based hour of the day in 24-hour (or "military") time.
     */
    public int hour { get; private set; }
    
    /**
     * One-based hour of the day in 12-hour notation.
     */
    public int 12hour { get; private set; }
    
    /**
     * Zero-based minute of the {@link hour}.
     */
    public int minute { get; private set; }
    
    /**
     * Zero-based second of the {@link minute}.
     */
    public int second { get; private set; }
    
    /**
     * Indicates if post-meridiem.
     */
    public bool is_pm { get { return hour >= 12; } }
    
    /**
     * Generate a new {@link WallTime} object with the specified values.
     *
     * Note that hour must be in 24-hour time.
     *
     * Values will be clamped to create a valid time.
     */
    public WallTime(int hour, int minute, int second) {
        this.hour = hour.clamp(MIN_HOUR, MAX_HOUR);
        this.minute = minute.clamp(MIN_MINUTE, MAX_MINUTE);
        this.second = second.clamp(MIN_SECOND, MAX_SECOND);
        
        if (hour == 0)
            12hour = 12;
        else if (hour > 12)
            12hour = hour - 12;
        else
            12hour = hour;
    }
    
    /**
     * Called from Calendar.init().
     */
    internal static void init() {
        earliest = new WallTime(MIN_HOUR, MIN_MINUTE, MIN_SECOND);
        latest = new WallTime(MAX_HOUR, MAX_MINUTE, MAX_SECOND);
    }
    
    /**
     * Called from Calendar.terminate().
     */
    internal static void terminate() {
        earliest = null;
        latest = null;
    }
    
    /**
     * Attempt to convert a string into {@link WallTime}.
     *
     * 24-hour and 12-hour time is recognized, as are localized versions of AM and PM.  If the time
     * was "liberally" parsed (in other words, "8" is converted to 8am), the returned flag is
     * cleared.
     */
    public static WallTime? parse(string str, out bool strictly_parsed) {
        strictly_parsed = false;
        
        string token = str.strip().casefold();
        if (String.is_empty(token))
            return null;
        
        // look for words that mean specific times
        if (token == MIDNIGHT.casefold()) {
            strictly_parsed = true;
            
            return new WallTime(0, 0, 0);
        } else if (token == NOON.casefold()) {
            strictly_parsed = true;
            
            return new WallTime(12, 0, 0);
        }
        
        // look for meridiem tacked on to end
        bool pm = false;
        bool meridiem_unknown = false;
        if (token.has_suffix(FMT_AM.casefold())) {
            token = token.slice(0, token.length - FMT_AM.casefold().length);
        } else if (token.has_suffix(FMT_BRIEF_AM.casefold())) {
            token = token.slice(0, token.length - FMT_BRIEF_AM.casefold().length);
        } else if (token.has_suffix(FMT_PM.casefold())) {
            token = token.slice(0, token.length - FMT_PM.casefold().length);
            pm = true;
        } else if (token.has_suffix(FMT_BRIEF_PM.casefold())) {
            token = token.slice(0, token.length - FMT_BRIEF_PM.casefold().length);
            pm = true;
        } else {
            meridiem_unknown = true;
        }
        
        // remove colon (can be present for 12- or 24-hour time)
        token = token.replace(":", "");
        int length = token.length;
        
        // rest of string better be numeric and under the common lengths for specifying time
        if (!String.is_numeric(token) || length == 0 || length > 4)
            return null;
        
        // look for 24-hour time or a fully-detailed 12-hour time
        if ((length == 3 || length == 4)) {
            int h, m;
            if (length == 3) {
                h = int.parse(token.slice(0, 1));
                m = int.parse(token.slice(1, 3));
            } else {
                h = int.parse(token.slice(0, 2));
                m = int.parse(token.slice(2, 4));
            }
            
            // only convert 12hr -> 24hr if meridiem is known, is PM, and not 12pm (which is 12
            // in 24-hour time as well)
            if (!meridiem_unknown && pm && h != 12)
                h += 12;
            
            // accept "24:00" or "2400" as midnight
            if (h == 24 && m == 0)
                h = 0;
            
            // basic bounds checking; WallTime ctor will clamp, but for parsing prefer to be a
            // little strict in this case
            if (h < MIN_HOUR || h > MAX_HOUR || m < MIN_MINUTE || m > MAX_MINUTE)
                return null;
            
            strictly_parsed = true;
            
            return new WallTime(h, m, 0);
        }
        
        // otherwise, treat as short-form 12-hour time (even if meridiem is unknown, i.e. "8" is
        // treated as "8:00am" ... 12pm is 12 in 24-hour clock
        int h = int.parse(token);
        if (!meridiem_unknown && pm && h != 12)
            h += 12;
        
        // accept "24" as midnight
        if (h == 24)
            h = 0;
        
        // basic bounds checking to avoid WallTime ctor clamping
        if (h < MIN_HOUR || h > MAX_HOUR)
            return null;
        
        strictly_parsed = !meridiem_unknown;
        
        return new WallTime(h, 0, 0);
    }
    
    /**
     * Returns {@link WallTime} adjusted before or after this one.
     *
     * To subtract time, use a negative value.
     *
     * Like a wall clock, this will rollover to the next or previous day if enough time is
     * specified.  When this occurs, it's indicated in the rollover bool as an out result.
     */
    public WallTime adjust(int value, TimeUnit unit, out bool rollover) {
        if (value == 0) {
            rollover = false;
            
            return this;
        }
        
        int new_hour = hour;
        int new_minute = minute;
        int new_second = second;
        
        switch (unit) {
            case TimeUnit.HOUR:
                adjust_hour(ref new_hour, value, out rollover);
            break;
            
            case TimeUnit.MINUTE:
                adjust_minute(ref new_hour, ref new_minute, value, out rollover);
            break;
            
            case TimeUnit.SECOND:
                adjust_second(ref new_hour, ref new_minute, ref new_second, value, out rollover);
            break;
            
            default:
                assert_not_reached();
        }
        
        return new WallTime(new_hour, new_minute, new_second);
    }
    
    private void adjust_hour(ref int current_hour, int value, out bool rollover) {
        if (value == 0) {
            rollover = false;
            
            return;
        }
        
        // only add/subtract the fraction of 24-hours from the value; adding/subtracting 24 hours
        // (or multiple) is treated as identity operation for wall clock time
        int rem = value.abs() % HOURS_PER_DAY;
        current_hour += (value > 0) ? rem : 0 - rem;
        
        // under/overflow
        if (current_hour < 0) {
            current_hour = HOURS_PER_DAY - current_hour.abs();
            rollover = true;
        } else if (current_hour >= HOURS_PER_DAY) {
            current_hour -= HOURS_PER_DAY;
            rollover = true;
        } else if (value.abs() >= HOURS_PER_DAY) {
            rollover = true;
        } else {
            rollover = false;
        }
    }
    
    private void adjust_minute(ref int current_hour, ref int current_minute, int value, out bool rollover) {
        if (value == 0) {
            rollover = false;
            
            return;
        }
        
        int hours = value.abs() / MINUTES_PER_HOUR;
        adjust_hour(ref current_hour, value > 0 ? hours : 0 - hours, out rollover);
        
        int rem = value.abs() % MINUTES_PER_HOUR;
        current_minute += (value > 0) ? rem : 0 - rem;
        
        // under/overflow ... above logic prevents under/overflow of more than 1 hour
        if (current_minute < 0) {
            current_minute = MINUTES_PER_HOUR - current_minute.abs();
            bool under_rollover;
            adjust_hour(ref current_hour, -1, out under_rollover);
            rollover = rollover || under_rollover;
        } else if (current_minute >= MINUTES_PER_HOUR) {
            current_minute -= MINUTES_PER_HOUR;
            bool over_rollover;
            adjust_hour(ref current_hour, 1, out over_rollover);
            rollover = rollover || over_rollover;
        }
    }
    
    private void adjust_second(ref int current_hour, ref int current_minute, ref int current_second,
        int value, out bool rollover) {
        if (value == 0) {
            rollover = false;
            
            return;
        }
        
        int minutes = value.abs() / SECONDS_PER_MINUTE;
        adjust_minute(ref current_hour, ref current_minute, (value > 0) ? minutes : 0 - minutes,
            out rollover);
        
        int rem = value.abs() % SECONDS_PER_MINUTE;
        current_second += (value > 0) ? rem : 0 - rem;
        
        // under/overflow ... above logic prevents under/overflow of more than 1 minute
        if (current_second < 0) {
            current_second = SECONDS_PER_MINUTE - current_second.abs();
            bool under_rollover;
            adjust_minute(ref current_hour, ref current_minute, -1, out under_rollover);
            rollover = rollover || under_rollover;
        } else if (current_second >= SECONDS_PER_MINUTE) {
            current_second -= SECONDS_PER_MINUTE;
            bool over_rollover;
            adjust_minute(ref current_hour, ref current_minute, 1, out over_rollover);
            rollover = rollover || over_rollover;
        }
    }
    
    /**
     * Round a unit of the {@link WallTime} to a multiple of a supplied value.
     *
     * By rounding wall-clock time, not only is the unit in question rounded down to a multiple of
     * the supplied value, but the lesser units are truncated to zero.  Thus, 17:23:54 rounded down
     * to a multiple of 10 minutes returns 17:20:00.
     *
     * If the {@link TimeUnit} is already a multiple of the value, no change is made (although
     * there's no guarantee that the same WallTime instance will be returned, especially if the
     * lesser units are truncated).
     *
     * A multiple of zero or a negative value is always rounded to the current WallTime.
     *
     * TODO: An interface to round up (which will need to deal with overflow).
     */
    public WallTime round_down(int multiple, TimeUnit time_unit) {
        if (multiple <= 0)
            return this;
        
        // get value being manipulated
        int current;
        switch (time_unit) {
            case TimeUnit.HOUR:
                current = hour;
            break;
            
            case TimeUnit.MINUTE:
                current = minute;
            break;
            
            case TimeUnit.SECOND:
                current = second;
            break;
            
            default:
                assert_not_reached();
        }
        
        // round down and watch for underflow (which shouldn't happen)
        int rounded = current - (current % multiple.abs());
        if (rounded < 0)
            rounded = 0;
        
        // return new value
        switch (time_unit) {
            case TimeUnit.HOUR:
                return new WallTime(rounded, 0, 0);
            
            case TimeUnit.MINUTE:
                return new WallTime(hour, rounded, 0);
            
            case TimeUnit.SECOND:
                return new WallTime(hour, minute, rounded);
            
            default:
                assert_not_reached();
        }
    }
    
    /**
     * Returns a prettified, localized user-visible string.
     *
     * The string respects {@link System.is_24hr}.
     */
    public string to_pretty_string(PrettyFlag flags) {
        bool include_sec = (flags & PrettyFlag.INCLUDE_SECONDS) != 0;
        bool optional_min = (flags & PrettyFlag.OPTIONAL_MINUTES) != 0;
        bool meridiem_post_only = (flags & PrettyFlag.MERIDIEM_POST_ONLY) != 0;
        bool brief_meridiem = (flags & PrettyFlag.BRIEF_MERIDIEM) != 0;
        bool is_24hr = System.is_24hr;
        
        unowned string pm = brief_meridiem ? FMT_BRIEF_PM : FMT_PM;
        unowned string am = brief_meridiem ? FMT_BRIEF_AM : FMT_AM;
        
        unowned string meridiem;
        if (is_24hr)
            meridiem = "";
        else if (meridiem_post_only)
            meridiem = is_pm ? pm : "";
        else
            meridiem = is_pm? pm : am;
        
        // Not marked for translation on thw assumption that a 12-hour hour followed by the meridiem
        // isn't something that varies between locales, on the assumption that the user has
        // specified 12-hour time to begin with ... don't allow for 24-hour time because it doesn't
        // look right (especially early hours, i.e. "0", "2")
        if (optional_min && minute == 0 && !is_24hr)
            return "%d%s".printf(is_24hr ? hour : 12hour, meridiem);
        
        if (!include_sec) {
            // hour and minutes only
            if (is_24hr)
                return String.reduce_whitespace(FMT_24HOUR_MIN.printf(hour, minute));
            
            return String.reduce_whitespace(FMT_12HOUR_MIN_MERIDIEM.printf(12hour, minute, meridiem));
        }
        
        // the full package
        if (is_24hr)
            return String.reduce_whitespace(FMT_24HOUR_MIN_SEC.printf(hour, minute, second));
        
        return String.reduce_whitespace(FMT_12HOUR_MIN_SEC_MERIDIEM.printf(12hour, minute, second, meridiem));
    }
    
    public int compare_to(WallTime other) {
        if (this == other)
            return 0;
        
        int diff = hour - other.hour;
        if (diff != 0)
            return diff;
        
        diff = minute - other.minute;
        if (diff != 0)
            return diff;
        
        return second - other.second;
    }
    
    public bool equal_to(WallTime other) {
        return compare_to(other) == 0;
    }
    
    public uint hash() {
        // since each unit is < 60, give each 6 bits (2^6 = 64) of space
        return ((uint) hour << 12) | ((uint) minute << 6) | (uint) second;
    }
    
    public override string to_string() {
        return to_pretty_string(PrettyFlag.INCLUDE_SECONDS);
    }
}

}

