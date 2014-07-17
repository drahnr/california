/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable representation of duration, as in a positive span of time.
 *
 * See [[https://tools.ietf.org/html/rfc5545#section-3.8.2.5]]
 */

public class Duration : BaseObject {
    /**
     * Number of absolute days the duration spans.
     */
    public uint64 days { get { return hours / WallTime.HOURS_PER_DAY; } }
    
    /**
     * Number of absolute hours the duration spans.
     */
    public uint64 hours { get { return minutes / WallTime.MINUTES_PER_HOUR; } }
    
    /**
     * Number of absolute minutes the duration spans.
     */
    public uint64 minutes { get { return seconds / WallTime.SECONDS_PER_MINUTE; } }
    
    /**
     * Number of absolute seconds the duration spans.
     */
    public uint64 seconds { get; private set; }
    
    public Duration(uint days = 0, uint hours = 0, uint64 minutes = 0, uint64 seconds = 0) {
        // internally stored as seconds
        this.seconds =
            (days * WallTime.SECONDS_PER_MINUTE * WallTime.MINUTES_PER_HOUR * WallTime.HOURS_PER_DAY)
            + (hours * WallTime.SECONDS_PER_MINUTE * WallTime.MINUTES_PER_HOUR)
            + (minutes * WallTime.SECONDS_PER_MINUTE)
            + seconds;
    }
    
    public override string to_string() {
        return "%ss".printf(seconds.to_string());
    }
}

}

