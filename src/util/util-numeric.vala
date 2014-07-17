/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Numeric {

/**
 * Returns the value if it is greater than or equal to floor, floor otherwise.
 */
public inline int floor_int(int value, int floor) {
    return (value >= floor) ? value : floor;
}

}

