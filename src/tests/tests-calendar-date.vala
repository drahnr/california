/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

private class CalendarDate : UnitTest.Harness {
    public CalendarDate() {
        add_case("clamp-start", clamp_start);
        add_case("clamp-end", clamp_end);
        add_case("clamp-both", clamp_both);
        add_case("clamp-neither", clamp_neither);
        add_case("difference-pos", difference_pos);
        add_case("difference-neg", difference_neg);
        add_case("upcoming-inclusive", upcoming_inclusive);
        add_case("upcoming-exclusive", upcoming_exclusive);
        add_case("prior-inclusive", prior_inclusive);
        add_case("prior-exclusive", prior_exclusive);
        add_case("upcoming-today", upcoming_today);
        add_case("upcoming-next-week", upcoming_next_week);
        add_case("day-of-week-position-1", day_of_week_position_1);
        add_case("day-of-week-position-2", day_of_week_position_2);
        add_case("day-of-week-position-3", day_of_week_position_3);
        add_case("day-of-week-position-4", day_of_week_position_4);
        add_case("day-of-week-position-5", day_of_week_position_5);
    }
    
    protected override void setup() throws Error {
        Calendar.init();
    }
    
    protected override void teardown() {
        Calendar.terminate();
    }
    
    private Calendar.Date from_today(int days) {
        return Calendar.System.today.adjust(days);
    }
    
    private Calendar.DateSpan span_from_today(int start_days, int end_days) {
        return new Calendar.DateSpan(from_today(start_days), from_today(end_days));
    }
    
    private bool clamp_start() throws Error {
        Calendar.DateSpan span = span_from_today(0, 5);
        Calendar.DateSpan clamp = span_from_today(1, 5);
        Calendar.DateSpan adj = span.clamp_between(clamp);
        
        return adj.start_date.equal_to(clamp.start_date) && adj.end_date.equal_to(span.end_date);
    }
    
    private bool clamp_end() throws Error {
        Calendar.DateSpan span = span_from_today(0, 5);
        Calendar.DateSpan clamp = span_from_today(0, 4);
        Calendar.DateSpan adj = span.clamp_between(clamp);
        
        return adj.start_date.equal_to(span.start_date) && adj.end_date.equal_to(clamp.end_date);
    }
    
    private bool clamp_both() throws Error {
        Calendar.DateSpan span = span_from_today(0, 5);
        Calendar.DateSpan clamp = span_from_today(1, 4);
        Calendar.DateSpan adj = span.clamp_between(clamp);
        
        return adj.start_date.equal_to(clamp.start_date) && adj.end_date.equal_to(clamp.end_date);
    }
    
    private bool clamp_neither() throws Error {
        Calendar.DateSpan span = span_from_today(0, 5);
        Calendar.DateSpan clamp = span_from_today(-1, 6);
        Calendar.DateSpan adj = span.clamp_between(clamp);
        
        return adj.start_date.equal_to(span.start_date) && adj.end_date.equal_to(span.end_date);
    }
    
    private bool difference_pos() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date tomorrow = today.next();
        
        return today.difference(tomorrow) == 1;
    }
    
    private bool difference_neg() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date day_before_yesterday = today.previous().previous();
        
        return today.difference(day_before_yesterday) == -2;
    }
    
    private bool upcoming(bool inclusive, out string? dump) throws Error {
        dump = null;
        
        Calendar.Date today = Calendar.System.today;
        
        foreach (Calendar.DayOfWeek dow in Calendar.DayOfWeek.all(Calendar.FirstOfWeek.SUNDAY)) {
            Calendar.Date upcoming = Calendar.System.today.upcoming(inclusive,
                date => date.day_of_week.equal_to(dow));
            int diff = today.difference(upcoming);
            
            dump = "%s - %s = %d".printf(today.to_string(), upcoming.to_string(), diff);
            
            if (!inclusive && diff == 0)
                return false;
            
            if (diff < 0 || diff > 7)
                return false;
        }
        
        return true;
    }
    
    private bool upcoming_inclusive(out string? dump) throws Error {
        return upcoming(true, out dump);
    }
    
    private bool upcoming_exclusive(out string? dump) throws Error {
        return upcoming(false, out dump);
    }
    
    private bool prior(bool inclusive, out string? dump) throws Error {
        dump = null;
        
        Calendar.Date today = Calendar.System.today;
        
        foreach (Calendar.DayOfWeek dow in Calendar.DayOfWeek.all(Calendar.FirstOfWeek.SUNDAY)) {
            Calendar.Date upcoming = Calendar.System.today.prior(inclusive,
                date => date.day_of_week.equal_to(dow));
            int diff = today.difference(upcoming);
            
            dump = "%s - %s = %d".printf(today.to_string(), upcoming.to_string(), diff);
            
            if (!inclusive && diff == 0)
                return false;
            
            if (diff > 0 || diff < -7)
                return false;
        }
        
        return true;
    }
    
    private bool prior_inclusive(out string? dump) throws Error {
        return prior(false, out dump);
    }
    
    private bool prior_exclusive(out string? dump) throws Error {
        return prior(false, out dump);
    }
    
    private bool upcoming_today() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date another_today = today.upcoming(true,
            date => date.day_of_week.equal_to(today.day_of_week));
        int diff = today.difference(another_today);
        
        return diff == 0;
    }
    
    private bool upcoming_next_week() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date next_week = today.upcoming(false,
            date => date.day_of_week.equal_to(today.day_of_week));
        int diff = today.difference(next_week);
        
        return diff == 7;
    }
    
    private bool test_dow_position(Calendar.Date date, int expected, out string? dump) throws Error {
        int position = date.day_of_month.week_of_month;
        
        dump = "%s position=%d, expected=%d".printf(date.to_string(), position, expected);
        
        return position == expected;
    }
    
    private Calendar.Date jun2014(int dom) throws Error {
        return new Calendar.Date(Calendar.DayOfMonth.for(dom), Calendar.Month.JUN,
            new Calendar.Year(2014));
    }
    
    private bool day_of_week_position_1(out string? dump) throws Error {
        return test_dow_position(jun2014(1), 1, out dump);
    }
    
    private bool day_of_week_position_2(out string? dump) throws Error {
        return test_dow_position(jun2014(9), 2, out dump);
    }
    
    private bool day_of_week_position_3(out string? dump) throws Error {
        return test_dow_position(jun2014(20), 3, out dump);
    }
    
    private bool day_of_week_position_4(out string? dump) throws Error {
        return test_dow_position(jun2014(23), 4, out dump);
    }
    
    private bool day_of_week_position_5(out string? dump) throws Error {
        return test_dow_position(jun2014(30), 5, out dump);
    }
}

}

