//
//  CharacterSet+Extension.swift
//  attentive-ios-sdk-framework
//

import Foundation

extension CharacterSet {
    /// Percent-encoding allow-set for values inside an
    /// `application/x-www-form-urlencoded` body or query string: `.urlQueryAllowed`
    /// minus the sub-delims that separate form fields (`&`, `=`) or have special
    /// decode semantics (`+` decodes as space in form parsers).
    ///
    /// Used by:
    /// - `ATTNEventURLProvider.setFormEncodedQuery` for the legacy `/e` query string.
    /// - `ATTNAPI.sendNewEvent` for the `/mobile` form-urlencoded body.
    static let attnFormEncodedAllowed: CharacterSet = {
        var chars = CharacterSet.urlQueryAllowed
        chars.remove("+")
        chars.remove("&")
        chars.remove("=")
        return chars
    }()
}
