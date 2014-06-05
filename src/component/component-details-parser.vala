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
            casefolded = token.casefold();
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
        foreach (string token in tokenized)
            list.add(new Token(token));
        
        stack = new Collection.LookaheadStack<Token>(list);
        
        parse();
    }
    
    private void parse() {
        for (;;) {
            Token? token = stack.pop();
            if (token == null)
                break;
            
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
        } else if (start_date != null && end_date != null) {
            event.set_event_date_span(new Calendar.DateSpan(start_date, end_date));
        }
        
        // other event details
        if (!String.is_empty(summary.str))
            event.summary = summary.str;
        
        if (!String.is_empty(location.str))
            event.location = location.str;
        
        // store full detail text in the event description for user and for debugging
        if (String.is_empty(event.description))
            event.description = details;
        else
            event.description += "\n" + details;
    }
    
    private bool parse_time(Token? specifier, bool strict) {
        if (specifier == null)
            return false;
        
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
        
        bool strictly_parsed;
        Calendar.WallTime? wall_time = Calendar.WallTime.parse(specifier.casefolded,
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
        
        if (end_time != null || duration != null)
            return false;
        
        duration = Calendar.Duration.parse(amount.casefolded, unit.casefolded);
        
        return duration != null;
    }
    
    private bool parse_delay(Token? amount, Token? unit) {
        if (amount == null || unit == null)
            return false;
        
        // Since delay is a way of specifying the start time, don't add if already known
        if (start_time != null)
            return false;
        
        Calendar.Duration? delay = Calendar.Duration.parse(amount.casefolded, unit.casefolded);
        if (delay == null)
            return false;
        
        start_time =
            Calendar.System.now.adjust_time((int) delay.minutes, Calendar.TimeUnit.MINUTE).to_wall_time();
        
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
        
        return (dow != null) ? Calendar.System.today.upcoming(dow, true) : null;
    }
    
    // Parses potential date specifiers into a specific calendar date
    private Calendar.Date? parse_day_month(Token day, Token mon, Calendar.Year? year = null) {
        // strip ordinal suffix if present
        string day_number = day.casefolded;
        foreach (string suffix in ORDINAL_SUFFIXES) {
            if (!String.is_empty(suffix) && day_number.has_suffix(suffix)) {
                day_number = day_number.slice(0, day_number.length - suffix.length);
                
                break;
            }
        }
        
        if (!String.is_numeric(day_number))
            return null;
        
        Calendar.Month? month = Calendar.Month.parse(mon.casefolded);
        if (month == null)
            return null;
        
        if (year == null)
            year = Calendar.System.today.year;
        
        try {
            return new Calendar.Date(Calendar.DayOfMonth.for(int.parse(day.casefolded)),
                month, year);
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
        else if (end_date == null)
            end_date = date;
        else
            return false;
        
        return true;
    }
    
    public override string to_string() {
        return "DetailsParser:%s".printf(event.to_string());
    }
}

}

