/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

public int run(string[] args) {
    // make warnings and criticals fatal to catch during tests
    GLib.Log.set_always_fatal(
        LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL);
    
    UnitTest.Harness.register(new String());
    UnitTest.Harness.register(new Iterable());
    UnitTest.Harness.register(new CalendarDate());
    UnitTest.Harness.register(new CalendarMonthSpan());
    UnitTest.Harness.register(new CalendarMonthOfYear());
    UnitTest.Harness.register(new CalendarWallTime());
    UnitTest.Harness.register(new QuickAdd());
    UnitTest.Harness.register(new QuickAddRecurring());
    
    return UnitTest.Harness.exec_all();
}

}

