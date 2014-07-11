/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California {

/**
 * Errors related to the {@link Backing} data sources.
 */

public errordomain BackingError {
    /**
     * Indicates an invalid value or out-of-bounds error.
     */
    INVALID,
    /**
     * Indicates a mismatch (i.e. {@link Component.UID})
     */
    MISMATCH,
    /**
     * The method or object is unavailable due to a state change (not open or removed).
     */
    UNAVAILABLE,
    /**
     * The object or identifier is not recognized.
     */
    UNKNOWN
}

}

