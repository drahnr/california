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
        add_case("upcoming", upcoming);
        add_case("prior", prior);
        add_case("upcoming-today", upcoming_today);
        add_case("upcoming-next-week", upcoming_next_week);
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
    
    private bool upcoming() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date upcoming_fri = today.upcoming(Calendar.DayOfWeek.FRI, false);
        int diff = today.difference(upcoming_fri);
        
        return diff > 0 && diff <= 7;
    }
    
    private bool prior() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date prior_tue = today.prior(Calendar.DayOfWeek.TUE, false);
        int diff = today.difference(prior_tue);
        
        return diff < 0 && diff >= -7;
    }
    
    private bool upcoming_today() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date another_today = today.upcoming(today.day_of_week, true);
        int diff = today.difference(another_today);
        
        return diff == 0;
    }
    
    private bool upcoming_next_week() throws Error {
        Calendar.Date today = Calendar.System.today;
        Calendar.Date next_week = today.upcoming(today.day_of_week, false);
        int diff = today.difference(next_week);
        
        return diff == 7;
    }
}

}

