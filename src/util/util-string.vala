/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.String {

public char NUL = '\0';

public inline bool is_empty(string? str) {
    return (str == null) || (str[0] == NUL);
}

public int stricmp(string a, string b) {
    return strcmp(a.casefold(), b.casefold());
}

public uint ci_hash(string str) {
    return str.casefold().hash();
}

public bool ci_equal(string a, string b) {
    return stricmp(a, b) == 0;
}

/**
 * Removes redundant whitespace (including tabs and newlines) and strips whitespace from beginning
 * and end of string.
 */
public string reduce_whitespace(string str) {
    if (str[0] == NUL)
        return str;
    
    StringBuilder builder = new StringBuilder();
    unichar ch;
    unichar last_ch = NUL;
    int index = 0;
    while (str.get_next_char(ref index, out ch)) {
        // if space but last char not NUL (i.e. this is not the first character, a space) and the
        // last char was not a space, append, otherwise drop
        if (ch.isspace()) {
            if (last_ch != NUL && !last_ch.isspace())
                builder.append_unichar(ch);
        } else {
            builder.append_unichar(ch);
        }
        
        last_ch = ch;
    }
    
    // due to get_next_char()'s interface, don't know when char is last, so it's possible for trailing
    // whitespace to exist
    return builder.str.chomp();
}

/**
 * Returns true if every character in the string is a numeric digit.
 */
public bool is_numeric(string? str) {
    if (is_empty(str))
        return false;
    
    unichar ch;
    int index = 0;
    while (str.get_next_char(ref index, out ch)) {
        if (!ch.isdigit())
            return false;
    }
    
    return true;
}

/**
 * Removes leading characters from throughout the string.
 *
 * Both the leading character and what constitutes tokens can be specified.
 *
 * Results are undefined if the leading character is also found in the delimiter string.
 */
public string? remove_leading_chars(string? str, unichar ch, string delims = " ") {
    if (is_empty(str))
        return str;
    
    StringBuilder builder = new StringBuilder();
    unichar current_ch;
    int index = 0;
    bool leading = true;
    while (str.get_next_char(ref index, out current_ch)) {
        // if character is a delimiter, reset state, append, and move on
        if (delims.index_of_char(current_ch) >= 0) {
            leading = true;
            builder.append_unichar(current_ch);
            
            continue;
        }
        
        // if looking for leading characters and this matches, drop on the floor
        if (leading && current_ch == ch)
            continue;
        
        // done looking for leading characters until the next delimiter
        leading = false;
        builder.append_unichar(current_ch);
    }
    
    return builder.str;
}

}

