/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * Declaration of which day (Monday or Sunday) is the preferred first day of the week.
 */

public enum FirstOfWeek {
    MONDAY,
    SUNDAY,
    
    /**
     * Default {@link FirstOfWeek}.
     */
    DEFAULT = SUNDAY;
    
    /**
     * Converts the {@link FirstOfWeek} into an actual {@link DayOfWeek}.
     */
    public DayOfWeek as_day_of_week() {
        switch (this) {
            case MONDAY:
                return DayOfWeek.MON;
            
            case SUNDAY:
                return DayOfWeek.SUN;
            
            default:
                assert_not_reached();
        }
    }
}

}
