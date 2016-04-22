//
//  String+Yep.swift
//  Yep
//
//  Created by kevinzhow on 15/4/2.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import Foundation
import RealmSwift

extension String {
    
    func toDate() -> NSDate? {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = dateFormatter.dateFromString(self) {
            return date
        } else {
            return nil
        }
    }
}

extension String {

    enum TrimmingType {
        case Whitespace
        case WhitespaceAndNewline
    }

    func trimming(trimmingType: TrimmingType) -> String {
        switch trimmingType {
        case .Whitespace:
            return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        case .WhitespaceAndNewline:
            return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        }
    }

    var yep_removeAllWhitespaces: String {
        return self.stringByReplacingOccurrencesOfString(" ", withString: "").stringByReplacingOccurrencesOfString(" ", withString: "")
    }

    var yep_removeAllNewLines: String {
        return self.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()).joinWithSeparator("")
    }

    func yep_truncate(length: Int, trailing: String? = nil) -> String {
        if self.characters.count > length {
            return self.substringToIndex(self.startIndex.advancedBy(length)) + (trailing ?? "")
        } else {
            return self
        }
    }

    var yep_truncatedForFeed: String {
        return yep_truncate(120, trailing: "...")
    }
}

extension String {

    func yep_rangeFromNSRange(nsRange: NSRange) -> Range<Index>? {

        let from16 = utf16.startIndex.advancedBy(nsRange.location, limit: utf16.endIndex)
        let to16 = from16.advancedBy(nsRange.length, limit: utf16.endIndex)

        guard let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self) else {
                return nil
        }

        return from ..< to
    }

    func yep_NSRangeFromRange(range: Range<Index>) -> NSRange {

        let utf16view = self.utf16
        let from = String.UTF16View.Index(range.startIndex, within: utf16view)
        let to = String.UTF16View.Index(range.endIndex, within: utf16view)

        return NSMakeRange(utf16view.startIndex.distanceTo(from), from.distanceTo(to))
    }
}

extension String {

    func yep_mentionedMeInRealm(realm: Realm) -> Bool {

        guard let myUserID = YepUserDefaults.userID.value, me = userWithUserID(myUserID, inRealm: realm) else {
            return false
        }

        let username = me.username

        if !username.isEmpty {
            if self.containsString("@\(username)") {
                return true
            }
        }

        return false
    }

    func yep_mentionWordInIndex(index: Int) -> (wordString: String, mentionWordRange: Range<Index>)? {

        //println("startIndex: \(startIndex), endIndex: \(endIndex), index: \(index), length: \((self as NSString).length), count: \(self.characters.count)")

        guard index > 0 else {
            return nil
        }

        let nsRange = NSMakeRange(index, 0)
        guard let range = self.yep_rangeFromNSRange(nsRange) else {
            return nil
        }
        let index = range.startIndex

        var wordString: String?
        var wordRange: Range<Index>?

        self.enumerateSubstringsInRange(startIndex..<endIndex, options: [.ByWords, .Reverse]) { (substring, substringRange, enclosingRange, stop) -> () in

            //println("substring: \(substring)")
            //println("substringRange: \(substringRange)")
            //println("enclosingRange: \(enclosingRange)")

            if substringRange.contains(index) {
                wordString = substring
                wordRange = substringRange
                stop = true
            }
        }

        guard let _wordString = wordString, _wordRange = wordRange else {
            return nil
        }

        guard _wordRange.startIndex != startIndex else {
            return nil
        }

        let mentionWordRange = _wordRange.startIndex.advancedBy(-1)..<_wordRange.endIndex

        let mentionWord = substringWithRange(mentionWordRange)

        guard mentionWord.hasPrefix("@") else {
            return nil
        }

        return (_wordString, mentionWordRange)
    }
}

extension String {

    var yep_embeddedURLs: [NSURL] {

        guard let detector = try? NSDataDetector(types: NSTextCheckingType.Link.rawValue) else {
            return []
        }

        var URLs = [NSURL]()

        detector.enumerateMatchesInString(self, options: [], range: NSMakeRange(0, (self as NSString).length)) { result, flags, stop in

            if let URL = result?.URL {
                URLs.append(URL)
            }
        }

        return URLs
    }

    var yep_firstImageURL: NSURL? {

        let URLs = yep_embeddedURLs

        guard !URLs.isEmpty else {
            return nil
        }

        let imageExtentions = [
            "png",
            "jpg",
            "jpeg",
        ]

        for URL in URLs {
            if let pathExtension = URL.pathExtension?.lowercaseString {
                if imageExtentions.contains(pathExtension) {
                    return URL
                }
            }
        }

        return nil
    }
}

extension String {

    func yep_hightlightSearchKeyword(keyword: String, baseFont: UIFont, baseColor: UIColor) -> NSAttributedString? {

        return yep_highlightKeyword(keyword, withColor: UIColor.yepTintColor(), baseFont: baseFont, baseColor: baseColor)
    }

    func yep_highlightKeyword(keyword: String, withColor color: UIColor, baseFont: UIFont, baseColor: UIColor) -> NSAttributedString? {

        guard !keyword.isEmpty else {
            return nil
        }

        let text = self
        let attributedString = NSMutableAttributedString(string: text)
        let textRange = NSMakeRange(0, (text as NSString).length)

        attributedString.addAttribute(NSForegroundColorAttributeName, value: baseColor, range: textRange)
        attributedString.addAttribute(NSFontAttributeName, value: baseFont, range: textRange)

        // highlight keyword

        let highlightTextAttributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: color,
        ]

        let highlightExpression = try! NSRegularExpression(pattern: keyword, options: [.CaseInsensitive])

        highlightExpression.enumerateMatchesInString(text, options: NSMatchingOptions(), range: textRange, usingBlock: { result, flags, stop in

            if let result = result {
                attributedString.addAttributes(highlightTextAttributes, range: result.range )
            }
        })

        return attributedString
    }

    func yep_highlightEmphasisTagWithColor(color: UIColor, baseFont: UIFont, baseColor: UIColor) -> NSAttributedString? {

        let text = self
        let textRange = NSMakeRange(0, (text as NSString).length)

        let keywordExpression = try! NSRegularExpression(pattern: "<em>(.+?)</em>", options: [.CaseInsensitive])

        let matches = keywordExpression.matchesInString(self, options: [], range: textRange)
        let keywords: [String] = matches.map({
            let matchRange = $0.rangeAtIndex(1)
            let keyword = (text as NSString).substringWithRange(matchRange)
            return keyword
        })

        println("EmphasisTag keywords: \(keywords)")

        guard !keywords.isEmpty else {
            return nil
        }

        let emphasisTagExpression = try! NSRegularExpression(pattern: "</?em>", options: [.CaseInsensitive])
        let plainText = emphasisTagExpression.stringByReplacingMatchesInString(text, options: [], range: textRange, withTemplate: "")
        let plainTextRange = NSMakeRange(0, (plainText as NSString).length)

        println("EmphasisTag plainText: \(plainText)")

        let attributedString = NSMutableAttributedString(string: plainText)

        let highlightTextAttributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: color,
        ]

        keywords.forEach({
            if let highlightExpression = try? NSRegularExpression(pattern: $0, options: [.CaseInsensitive]) {

                highlightExpression.enumerateMatchesInString(plainText, options: NSMatchingOptions(), range: plainTextRange, usingBlock: { result, flags, stop in

                    if let result = result {
                        attributedString.addAttributes(highlightTextAttributes, range: result.range )
                    }
                })
            }
        })
        
        return attributedString
    }
}
