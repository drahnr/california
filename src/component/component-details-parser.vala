/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Component {

/**
 * Parse the details of a user-entered string into an {@link Event}.
 *
 * DetailsParser makes no claims of advanced natural language parsing or interpretation.  It merely
 * looks for keywords and patterns within the tokenized stream and guesses what Event details
 * they refer to.
 *
 * The fields the parser attempts to fill-in are {@link Event.date_span} (or
 * {@link Event.exact_time_span}, {@link Event.summary}, and {@link Event.location}.  Other fields
 * may be considered in the future.
 */

public class DetailsParser : BaseObject {
    private class Token : BaseObject, Gee.Hashable<Token> {
        public string original;
        public string casefolded;
        
        public Token(string token) {
            original = token;
            casefolded = from_string(token).filter(c => !c.ispunct()).to_string(c => c.to_string()) ?? "";
        }
        
        public bool equal_to(Token other) {
            return (this != other) ? original == other.original : true;
        }
        
        public uint hash() {
            return original.hash();
        }
        
        public override string to_string() {
            return original;
        }
    }
    
    /**
     * The original string of text generating the {@link event}.
     *
     * If null is passed to constructor, this will be the empty string.
     */
    public string details { get; private set; }
    
    /**
     * The generated {@link Event}.
     */
    public Component.Event event { get; private set; }
    
    private Collection.LookaheadStack<Token> stack;
    private StringBuilder summary = new StringBuilder();
    private StringBuilder location = new StringBuilder();
    private Calendar.WallTime? start_time = null;
    private bool start_time_strict = true;
    private Calendar.WallTime? end_time = null;
    private bool end_time_strict = true;
    private Calendar.Date? start_date = null;
    private Calendar.Date? end_date = null;
    private Calendar.Duration? duration = null;
    private bool adding_location = false;
    private RecurrenceRule? rrule = null;
    
    /**
     * Parses a user-entered string of event details into an {@link Event}.
     *
     * This always generates an Event, but very little in it may be prepared.  Its backup case
     * is to use the details string as a summary and leave all other fields empty.  The caller
     * should complete the other fields to generate a valid VEVENT.
     *
     * If the caller wishes to "pre-fill" the Event with certain details, it can supply an Event
     * that will be used for initial values.  This will have an effect on the parser; in particular,
     * with those details pre-filled in, values detected in the parsed string that would normally
     * be used in their place will be dropped.  In other words, adding initial values will remove
     * what the user can then add in their own string.
     *
     * The {@link details} supplied by the user are stored in {@link Event.description} verbatim.
     *
     * If the details string is empty, a blank Event is generated.
     */
    public DetailsParser(string? details, Backing.CalendarSource? calendar_source, Event? initial = null) {
        event = initial ?? new Component.Event.blank();
        event.calendar_source = calendar_source;
        this.details = details ?? "";
        
        // pull out details from the initial Event and add to the local state, which is then
        // supplanted (but not replaced) by parsed information
        if (initial != null) {
            if (!String.is_empty(initial.summary))
                summary.append(initial.summary.strip());
            
            if (!String.is_empty(initial.location))
                location.append(initial.location.strip());
            
            if (event.is_all_day) {
                start_date = event.date_span.start_date;
                end_date = event.date_span.end_date;
            } else if (event.exact_time_span != null) {
                start_date = event.exact_time_span.start_date;
                start_time = event.exact_time_span.start_exact_time.to_wall_time();
                start_time_strict = true;
                
                end_date = event.exact_time_span.end_date;
                end_time = event.exact_time_span.end_exact_time.to_wall_time();
                end_time_strict = true;
            }
        }
        
        // tokenize the string and arrange as a stack for the parser
        string[] tokenized = String.reduce_whitespace(this.details).split(" ");
        Gee.LinkedList<Token> list = new Gee.LinkedList<Token>();
        foreach (string token in tokenized) {
            if (!String.is_empty(token))
                list.add(new Token(token));
        }
        
        stack = new Collection.LookaheadStack<Token>(list);
        
        parse();
    }
    
    private void parse() {
        for (;;) {
            Token? token = stack.pop();
            if (token == null)
                break;
            
            // because whitespace and punctuation is stripped from the original token, it's possible
            // for the casefolded token to be empty
            if (String.is_empty(token.casefolded)) {
                add_text(token);
                
                continue;
            }
            
            // mark the stack branch for each parsing branch so if it fails the state can be
            // restored and the next branch's read-ahead gets a chance; don't restore on success
            // as each method is responsible for consuming all tokens it needs to complete its work
            // and no more.
            
            // look for prepositions indicating time or location follows; this depends on
            // translated strings, obviously, and does not apply to all languages, but we do what
            // we can here.
            
            // A time preposition suggests a specific point of time is being described in the
            // following token.  Don't require strict parsing of time ("8" -> "8am") because the
            // preposition offers a clue that a time is being specified.
            stack.mark();
            if (token.casefolded in TIME_PREPOSITIONS && parse_time(stack.pop(), false))
                continue;
            stack.restore();
            
            // A duration preposition suggests a specific amount of positive time is being described
            // by the next two tokens.
            stack.mark();
            if (token.casefolded in DURATION_PREPOSITIONS && parse_duration(stack.pop(), stack.pop()))
                continue;
            stack.restore();
            
            // A delay preposition suggests a specific point of time is being described by a
            // positive duration of time after the current time by the next two tokens.
            stack.mark();
            if (token.casefolded in DELAY_PREPOSITIONS && parse_delay(stack.pop(), stack.pop()))
                continue;
            stack.restore();
            
            // A recurring preposition suggests a regular occurrance is being described by the next
            // two tokens
            stack.mark();
            if (token.casefolded in RECURRING_PREPOSITIONS && parse_recurring(stack.pop()))
                continue;
            stack.restore();
            
            // only look for location prepositions if not already adding text to the location field
            if (!adding_location && token.casefolded in LOCATION_PREPOSITIONS) {
                // add current token (the preposition) to summary but not location (because location
                // tokens are added to summary, i.e. "dinner at John's" yields "John's" for location
                // and "dinner at John's" for summary)
                add_text(token);
                
                // now adding to both summary and location
                adding_location = true;
                
                continue;
            }
            
            // if a recurring rule has been started and are adding to it, drop common prepositions
            // that indicate linkage
            stack.mark();
            if (token.casefolded in COMMON_PREPOSITIONS) {
                if (rrule != null)
                    continue;
                
                if (parse_time(stack.pop(), true))
                    continue;
            }
            stack.restore();
            
            // if a recurring rule has not been started, look for keywords which transform the
            // event into one
            stack.mark();
            if (rrule == null && parse_recurring_indicator(token))
                continue;
            stack.restore();
            
            // if a recurring rule has been started, attempt to parse into additions for the rule
            stack.mark();
            if (rrule != null && parse_recurring(token))
                continue;
            stack.restore();
            
            // if this token and next describe a duration, use them
            stack.mark();
            if (parse_duration(token, stack.pop()))
                continue;
            stack.restore();
            
            // attempt to (strictly) parse into wall-clock time
            stack.mark();
            if (parse_time(token, true))
                continue;
            stack.restore();
            
            // append original to current text field(s) as fallback
            add_text(token);
        }
        
        //
        // assemble accumulated information in an Event, using defaults wherever appropriate
        //
        
        // track if end_date is "artificially" generated to complete the Event
        bool generated_end_date = (end_date == null);
        
        // if no start time or date but a duration was specified, assume start is now and use
        // duration for end time
        if (start_time == null && start_date == null && duration != null) {
            start_time = Calendar.System.now.to_wall_time();
            end_time =
                Calendar.System.now.adjust_time((int) duration.minutes, Calendar.TimeUnit.MINUTE).to_wall_time();
            duration = null;
        }
        
        // if a start time was described but not end time, use a 1 hour duration default
        bool midnight_crossed = false;
        if (start_time != null && end_time == null) {
            if (duration != null) {
                end_time = start_time.adjust((int) duration.minutes, Calendar.TimeUnit.MINUTE,
                    out midnight_crossed);
            } else {
                end_time = start_time.adjust(1, Calendar.TimeUnit.HOUR, out midnight_crossed);
            }
        }
        
        // if no start date was described but a start time was, assume for today *unless* midnight
        // was specified, in which case, tomorrow
        if (start_date == null && start_time != null) {
            start_date = Calendar.System.today;
            if (start_time.equal_to(Calendar.WallTime.earliest))
                start_date = start_date.next();
        }
        
        // if no end date was describe, assume ends today as well (unless midnight was crossed
        // due to duration)
        if (start_date != null && end_date == null)
            end_date = midnight_crossed ? start_date.next() : start_date;
        
        // Event start/end time, if specified
        if (start_time != null && end_time != null) {
            assert(start_date != null);
            assert(end_date != null);
            
            // look for midnight crossings
            if (start_time.compare_to(end_time) > 0)
                end_date = end_date.next();
            
            event.set_event_exact_time_span(new Calendar.ExactTimeSpan(
                new Calendar.ExactTime(Calendar.System.timezone, start_date, start_time),
                new Calendar.ExactTime(Calendar.System.timezone, end_date, end_time)
            ));
            
            // for parser, RRULE UNTIL is always DTEND's date unless a duration (i.e. a count, as
            // the parser doesn't set UNTIL elsewhere) is specified; parser only deals in date-based
            // recurrences, but don't add UNTIL if parser auto-generated DTEND, since that's us
            // filling in "obvious" details about the whole of the event that may not necessarily
            // apply to the recurrence rule
            if (rrule != null && !rrule.has_duration && !generated_end_date)
                rrule.set_recurrence_end_date(end_date);
        } else if (start_date != null && end_date != null) {
            event.set_event_date_span(new Calendar.DateSpan(start_date, end_date));
            
            // see above note about RRULE UNTIL and DTEND
            if (rrule != null && !rrule.has_duration && !generated_end_date)
                rrule.set_recurrence_end_date(end_date);
        }
        
        // recurrence rule, if specified
        if (rrule != null)
            event.make_recurring(rrule);
        
        // other event details
        if (!String.is_empty(summary.str))
            event.summary = summary.str;
        
        if (!String.is_empty(location.str))
            event.location = location.str;
    }
    
    private bool parse_time(Token? specifier, bool strict) {
        if (specifier == null)
            return false;
        
        // look for single-word date specifiers
        if (specifier.casefolded in UNIT_WEEKENDS) {
            Calendar.Date saturday = Calendar.System.today.upcoming(true,
                date => date.day_of_week == Calendar.DayOfWeek.SAT);
            Calendar.Date sunday = Calendar.System.today.upcoming(true,
                date => date.day_of_week == Calendar.DayOfWeek.SUN);
            
            return add_date(saturday) && add_date(sunday);
        }
        
        // look for day/month specifiers, in any order
        stack.mark();
        {
            Token? second = stack.pop();
            if (second != null) {
                Calendar.Date? date = parse_day_month(specifier, second);
                if (date == null)
                    date = parse_day_month(second, specifier);
                
                if (date != null && add_date(date))
                    return true;
            }
        }
        stack.restore();
        
        // look for day/month/year specifiers
        stack.mark();
        {
            Token? second = stack.pop();
            Token? third = stack.pop();
            if (second != null && third != null) {
                // try d/m/y followed by m/d/y ... every other combination seems overkill
                Calendar.Date? date = parse_day_month_year(specifier, second, third);
                if (date == null)
                    date = parse_day_month_year(second, specifier, third);
                
                if (date != null && add_date(date))
                    return true;
            }
        }
        stack.restore();
        
        // parse single specifier looking for date first, then time
        Calendar.Date? date = parse_relative_date(specifier);
        if (date != null && add_date(date))
            return true;
        
        // store locally so it can be modified w/o risk (tokens may be reused)
        string specifier_casefolded = specifier.casefolded;
        
        // if meridiem found in next token, append to specifier for WallTime.parse()
        bool found_meridiem = false;
        stack.mark();
        {
            Token? meridiem = stack.pop();
            if (meridiem != null
                && (meridiem.casefolded == Calendar.FMT_AM.casefold() || meridiem.casefolded == Calendar.FMT_PM.casefold())) {
                specifier_casefolded += meridiem.casefolded;
                found_meridiem = true;
            }
        }
        
        // swallow meridiem if being used for WallTime.parse()
        if (!found_meridiem)
            stack.restore();
        
        bool strictly_parsed;
        Calendar.WallTime? wall_time = Calendar.WallTime.parse(specifier_casefolded,
            out strictly_parsed);
        if (wall_time != null && !strictly_parsed && strict)
            return false;
        
        return (wall_time != null) ? add_wall_time(wall_time, strictly_parsed) : false;
    }
    
    // Add a duration to the event if not already specified and an end time has not already been
    // specified
    private bool parse_duration(Token? amount, Token? unit) {
        if (amount == null || unit == null)
            return false;
        
        // if setting up a recurring rule, duration can be used as a count
        if (rrule != null) {
            // if duration already specified, not interested
            if (rrule.has_duration)
                return false;
            
            // convert duration into unit appropriate to rrule ... note that only date-based
            // rrules are allowed by parser
            int count = -1;
            switch (rrule.freq) {
                case iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE:
                    if (unit.casefolded in UNIT_DAYS)
                        count = parse_amount(amount);
                break;
                
                case iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE:
                    if (unit.casefolded in UNIT_WEEKS)
                        count = parse_amount(amount);
                break;
                
                case iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE:
                    if (unit.casefolded in UNIT_MONTHS)
                        count = parse_amount(amount);
                break;
                
                case iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE:
                    if (unit.casefolded in UNIT_YEARS)
                        count = parse_amount(amount);
                break;
                
                default:
                    assert_not_reached();
            }
            
            if (count > 0) {
                rrule.set_recurrence_count(count);
                
                return true;
            }
        }
        
        // otherwise, if an end time or duration is already known, then done here
        if (end_time != null || duration != null)
            return false;
        
        duration = parse_amount_of_time(amount, unit);
        
        return duration != null;
    }
    
    private bool parse_delay(Token? amount, Token? unit) {
        if (amount == null || unit == null)
            return false;
        
        // Since delay is a way of specifying the start time, don't add if already known
        if (start_time != null)
            return false;
        
        Calendar.Duration? delay = parse_amount_of_time(amount, unit);
        if (delay == null)
            return false;
        
        start_time =
            Calendar.System.now.adjust_time((int) delay.minutes, Calendar.TimeUnit.MINUTE).to_wall_time();
        
        return true;
    }
    
    // Returns negative value if amount is invalid
    private int parse_amount(Token? amount) {
        if (amount == null)
            return -1;
        
        return String.is_numeric(amount.casefolded) ? int.parse(amount.casefolded) : -1;
    }
    
    // Returns negative value if ordinal is invalid
    private int parse_ordinal(Token? ordinal) {
        if (ordinal == null)
            return -1;
        
        // strip ordinal suffix if present
        string ordinal_number = ordinal.casefolded;
        foreach (string suffix in ORDINAL_SUFFIXES) {
            if (!String.is_empty(suffix) && ordinal_number.has_suffix(suffix)) {
                ordinal_number = ordinal_number.slice(0, ordinal_number.length - suffix.length);
                
                break;
            }
        }
        
        return String.is_numeric(ordinal_number) ? int.parse(ordinal_number) : -1;
    }
    
    private Calendar.Duration? parse_amount_of_time(Token? amount, Token? unit) {
        if (amount == null || unit == null)
            return null;
        
        int amt = parse_amount(amount);
        if (amt < 0)
            return null;
        
        if (unit.casefolded in UNIT_DAYS)
            return new Calendar.Duration(amt);
        
        if (unit.casefolded in UNIT_HOURS)
            return new Calendar.Duration(0, amt);
        
        if (unit.casefolded in UNIT_MINS)
            return new Calendar.Duration(0, 0, amt);
        
        return null;
    }
    
    // this can create a new RRULE if the token indicates a one-time event should be recurring
    private bool parse_recurring_indicator(Token? specifier) {
        // rrule can't already exist
        if (rrule != null || specifier == null)
            return false;
        
        if (specifier.casefolded == DAILY)
            return set_rrule_daily(1);
        
        if (specifier.casefolded == WEEKLY) {
            if (start_date != null)
                set_rrule_weekly(iterate<Calendar.DayOfWeek>(start_date.day_of_week).to_array(), 1);
            else
                set_rrule(iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE, 1);
            
            return true;
        }
        
        if (specifier.casefolded == YEARLY) {
            set_rrule(iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE, 1);
            
            return true;
        }
        
        if (specifier.casefolded in UNIT_WEEKDAYS)
            return set_rrule_weekly(Calendar.DayOfWeek.weekdays, 1);
        
        if (specifier.casefolded in UNIT_WEEKENDS)
            return set_rrule_weekly(Calendar.DayOfWeek.weekend_days, 1);
        
        return false;
    }
    
    // this can create a new RRULE or edit an existing one, but will not create multiple RRULEs
    // for the same VEVENT
    private bool parse_recurring(Token? specifier) {
        if (specifier == null)
            return false;
        
        // take ownership in case specifier is an ordinal amount
        Token? unit = specifier;
        
        // look for an amount modifying the specifier (creating an interval, i.e. "every 2 days"
        // or "every 2nd day", hence parsing for ordinal)
        bool is_ordinal = false;
        int interval = parse_ordinal(unit);
        if (interval >= 1) {
            unit = stack.pop();
            if (unit == null)
                return false;
            
            is_ordinal = true;
        } else {
            interval = 1;
        }
        
        // a day of the week
        Calendar.DayOfWeek? dow = Calendar.DayOfWeek.parse(unit.casefolded);
        if (dow != null) {
            Calendar.DayOfWeek[] by_days = iterate<Calendar.DayOfWeek>(dow).to_array();
            
            // if interval is an ordinal, the rule is for "nth day of the month", so it's a position
            // (i.e. "1st tuesday")
            if (!is_ordinal)
                return set_rrule_weekly(by_days, interval);
            else
                return set_rrule_nth_day_of_week(by_days, interval);
        }
        
        // "day"
        if (unit.casefolded in UNIT_DAYS)
            return set_rrule_daily(interval);
        
        // "weekday"
        if (unit.casefolded in UNIT_WEEKDAYS)
            return set_rrule_weekly(Calendar.DayOfWeek.weekdays, interval);
        
        // "weekend"
        if (unit.casefolded in UNIT_WEEKENDS)
            return set_rrule_weekly(Calendar.DayOfWeek.weekend_days, interval);
        
        //parse for date, and if so, treat as yearly event
        stack.mark();
        {
            if (unit == specifier)
                unit = stack.pop();
            
            if (unit != null) {
                Calendar.Date? date = parse_day_month(specifier, unit);
                if (date == null)
                    date = parse_day_month(unit, specifier);
                
                if (date != null)
                    return set_rrule_nth_day_of_year(date, 1);
            }
        }
        stack.restore();
        
        return false;
    }
    
    private void set_rrule(iCal.icalrecurrencetype_frequency freq, int interval) {
        rrule = new RecurrenceRule(freq);
        rrule.interval = interval;
        rrule.first_of_week = Calendar.System.first_of_week.as_day_of_week();
    }
    
    // Using the supplied by days, find the first upcoming start_date that matches one of them
    // that is also the position (unless zero, which means "any")
    private void set_byday_start_date(Calendar.DayOfWeek[]? by_days, int position) {
        assert(position >= 0);
        
        // find the earliest date in the by_days; if it's earlier than the start_date or the
        // start_date isn't defined, use the earliest
        if (by_days != null) {
            Gee.Set<Calendar.DayOfWeek> dows = from_array<Calendar.DayOfWeek>(by_days).to_hash_set();
             Calendar.Date earliest = Calendar.System.today.upcoming(true, (date) => {
                if (position != 0 && date.day_of_month.week_of_month != position)
                    return false;
                
                return dows.contains(date.day_of_week);
            });
            if (start_date == null || earliest.compare_to(start_date) < 0)
                start_date = earliest;
        }
        
        // no start_date at this point, then today is it
        if (start_date == null)
            start_date = Calendar.System.today;
    }
    
    // "every day"
    private bool set_rrule_daily(int interval) {
        if (rrule != null)
            return false;
        
        // no start_date at this point, then today is it
        if (start_date == null)
            start_date = Calendar.System.today;
        
        set_rrule(iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE, interval);
        
        return true;
    }
    
    // "every tuesday"
    private bool set_rrule_weekly(Calendar.DayOfWeek[]? by_days, int interval) {
        if (rrule == null)
            set_rrule(iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE, interval);
        else if (!rrule.is_weekly)
            return false;
        
        Gee.Map<Calendar.DayOfWeek?, int> map = from_array<Calendar.DayOfWeek>(by_days)
            .to_hash_map_as_keys<int>(dow => 0);
        rrule.add_by_rule(RecurrenceRule.ByRule.DAY, RecurrenceRule.encode_days(map));
        
        set_byday_start_date(by_days, 0);
        
        return true;
    }
    
    // "every 1st tuesday"
    private bool set_rrule_nth_day_of_week(Calendar.DayOfWeek[]? by_days, int position) {
        // Although a month can span 6 calendar weeks, a day of a week never appears in more than
        // five of them
        if (position < 1 || position > 5)
            return false;
        
        if (rrule == null)
            set_rrule(iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE, 1);
        else if (!rrule.is_monthly)
            return false;
        
        Gee.Map<Calendar.DayOfWeek?, int> map = from_array<Calendar.DayOfWeek>(by_days)
            .to_hash_map_as_keys<int>(dow => position);
        rrule.add_by_rule(RecurrenceRule.ByRule.DAY, RecurrenceRule.encode_days(map));
        
        set_byday_start_date(by_days, position);
        
        return true;
    }
    
    // "every july 4th"
    private bool set_rrule_nth_day_of_year(Calendar.Date date, int interval) {
        if (rrule == null)
            set_rrule(iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE, interval);
        else if (!rrule.is_yearly)
            return false;
        
        if (start_date == null)
            start_date = date;
        
        rrule.add_by_rule(RecurrenceRule.ByRule.YEAR_DAY, iterate<int>(date.day_of_year).to_array_list());
        
        return true;
    }
    
    // Adds the text to the summary and location field, if adding_location is set
    private void add_text(Token token) {
        // always add to summary
        add_to_builder(summary, token);
        
        // add to location if in that mode
        if (adding_location)
            add_to_builder(location, token);
    }
    
    private static void add_to_builder(StringBuilder builder, Token token) {
        // keep everything space-delimited
        if (!String.is_empty(builder.str))
            builder.append_unichar(' ');
        
        builder.append(token.original);
    }
    
    // Adds a time to the event, start time first, then end time, dropping thereafter
    private bool add_wall_time(Calendar.WallTime wall_time, bool strictly_parsed) {
        if (start_time == null) {
            start_time = wall_time;
            start_time_strict = strictly_parsed;
        } else if (end_time == null) {
            end_time = wall_time;
            end_time_strict = strictly_parsed;
        } else {
            return false;
        }
        
        return true;
    }
    
    // Parses a potential date specifier into a calendar date relative to today
    private Calendar.Date? parse_relative_date(Token token) {
        // attempt to parse into common words for relative dates
        if (token.casefolded == TODAY)
            return Calendar.System.today;
        else if (token.casefolded == TOMORROW)
            return Calendar.System.today.next();
        else if (token.casefolded == YESTERDAY)
            return Calendar.System.today.previous();
        
        // attempt to parse into day of the week
        Calendar.DayOfWeek? dow = Calendar.DayOfWeek.parse(token.casefolded);
        
        return (dow != null)
            ? Calendar.System.today.upcoming(true, date => date.day_of_week.equal_to(dow))
            : null;
    }
    
    // Parses potential date specifiers into a specific calendar date
    private Calendar.Date? parse_day_month(Token day, Token mon, Calendar.Year? year = null) {
        int day_ordinal = parse_ordinal(day);
        if (day_ordinal < 0)
            return null;
        
        Calendar.Month? month = Calendar.Month.parse(mon.casefolded);
        if (month == null)
            return null;
        
        if (year == null)
            year = Calendar.System.today.year;
        
        try {
            return new Calendar.Date(Calendar.DayOfMonth.for(day_ordinal), month, year);
        } catch (CalendarError calerr) {
            // probably an out-of-bounds day of month
            return null;
        }
    }
    
    // Parses potential date specifiers into a specific calendar date
    private Calendar.Date? parse_day_month_year(Token day, Token mon, Token yr) {
        if (!String.is_numeric(yr.casefolded))
            return null;
        
        // a *sane* year
        int year = int.parse(yr.casefolded);
        int current_year = Calendar.System.today.year.value;
        if (year < (current_year - 1) || (year > current_year + 10))
            return null;
        
        return parse_day_month(day, mon, new Calendar.Year(year));
    }
    
    // Adds a date to the event, start time first, then end time, dropping dates thereafter
    private bool add_date(Calendar.Date date) {
        if (start_date == null)
            start_date = date;
        else if (end_date == null && rrule == null)
            end_date = date;
        else if (rrule != null && rrule.until_date == null)
            rrule.set_recurrence_end_date(date);
        else
            return false;
        
        return true;
    }
    
    public override string to_string() {
        return "DetailsParser:%s".printf(event.to_string());
    }
}

}

