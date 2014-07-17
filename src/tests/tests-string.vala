/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

private class String : UnitTest.Harness {
    public String() {
        add_case("strip-zeroes-space", strip_zeroes_space);
        add_case("strip-zeroes-slash", strip_zeroes_slash);
        add_case("strip-zeroes-multiple", strip_zeroes_multiple);
        add_case("reduce-whitespace", reduce_whitespace);
        add_case("reduce-nonspace-whitespace", reduce_nonspace_whitespace);
    }
    
    protected override void setup() throws Error {
        Util.init();
    }
    
    protected override void teardown() {
        Util.terminate();
    }
    
    private bool strip_zeroes_space() throws Error {
        string result = California.String.remove_leading_chars("01 2 03 4", '0');
        
        return result == "1 2 3 4";
    }
    
    private bool strip_zeroes_slash() throws Error {
        string result = California.String.remove_leading_chars("01/2/03/4", '0', " /");
        
        return result == "1/2/3/4";
    }
    
    private bool strip_zeroes_multiple() throws Error {
        string result = California.String.remove_leading_chars("001/2/03/4", '0', " /");
        
        return result == "1/2/3/4";
    }
    
    private bool test_reduce_whitespace(string instr, string expected, out string? dump) throws Error {
        string result = California.String.reduce_whitespace(instr);
        
        dump = "\"%s\" => \"%s\", expected \"%s\"".printf(instr, result, expected);
        
        return result == expected;
    }
    
    private bool reduce_whitespace(out string? dump) throws Error {
        return test_reduce_whitespace("  a  b  c  ", "a b c", out dump);
    }
    
    private bool reduce_nonspace_whitespace(out string? dump) throws Error {
        return test_reduce_whitespace("\t\ta\n\nb\r\rc\t\t", "a\nb\rc", out dump);
    }
}

}

