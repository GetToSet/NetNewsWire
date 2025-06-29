//
//  ArticlePasteboardWriter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/6/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import RSCore

extension Article: @retroactive PasteboardWriterOwner {
	public var pasteboardWriter: NSPasteboardWriting {
		return ArticlePasteboardWriter(article: self)
	}
}

@objc final class ArticlePasteboardWriter: NSObject, NSPasteboardWriting {

	let article: Article
	static let articleUTI = "com.ranchero.article"
	static let articleUTIType = NSPasteboard.PasteboardType(rawValue: articleUTI)
	static let articleUTIInternal = "com.ranchero.NetNewsWire-Evergreen.internal.article"
	static let articleUTIInternalType = NSPasteboard.PasteboardType(rawValue: articleUTIInternal)

	private lazy var renderedHTML: String = {
		let rendering = ArticleRenderer.articleHTML(article: article, theme: ArticleThemesManager.shared.currentTheme)
		return "<meta charset=\"utf-8\">\n" + rendering.html
	}()

	init(article: Article) {
		self.article = article
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		var types = [ArticlePasteboardWriter.articleUTIType]

		if let _ = article.preferredURL {
			types += [.URL]
		}
		types += [.string, .html, ArticlePasteboardWriter.articleUTIInternalType]

		return types
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
		let plist: Any?

		switch type {
		case .html:
			return renderedHTML
		case .string:
			plist = plainText()
		case .URL:
			return article.preferredLink ?? ""
		case ArticlePasteboardWriter.articleUTIType:
			plist = exportDictionary()
		case ArticlePasteboardWriter.articleUTIInternalType:
			plist = internalDictionary()
		default:
			plist = nil
		}

		return plist
	}
}

private extension ArticlePasteboardWriter {

	func plainText() -> String {
		var s = ""

		if let title = article.title {
			s += "\(title)\n\n"
		}
		if let text = article.contentText {
			s += "\(text)\n\n"
		}
		else if let summary = article.summary {
			s += "\(summary)\n\n"
		}
		else if let html = article.contentHTML {
			let convertedHTML = html.convertingToPlainText()
			s += "\(convertedHTML)\n\n"
		}

		if let link = article.link {
			s += "URL: \(link)\n\n"
		}
		if let externalLink = article.externalLink {
			s += "external URL: \(externalLink)\n\n"
		}

		s += "Date: \(article.logicalDatePublished)\n\n"

		if let feed = article.webFeed {
			s += "Feed: \(feed.nameForDisplay)\n"
			if let homePageURL = feed.homePageURL {
				s += "Home page: \(homePageURL)\n"
			}
			s += "URL: \(feed.url)"
		}

		return s
	}

	private struct Key {
		static let articleID = "articleID" // database ID, unique per account
		static let uniqueID = "uniqueID" // unique ID, unique per feed (guid, or possibly calculated)
		static let feedURL = "feedURL"
		static let webFeedID = "webFeedID" // may differ from feedURL if coming from a syncing system
		static let title = "title"
		static let contentHTML = "contentHTML"
		static let contentText = "contentText"
		static let url = "url" // usually a permalink
		static let externalURL = "externalURL" // usually not a permalink
		static let summary = "summary"
		static let imageURL = "imageURL"
		static let bannerImageURL = "bannerImageURL"
		static let datePublished = "datePublished"
		static let dateModified = "dateModified"
		static let dateArrived = "dateArrived"
		static let read = "read"
		static let starred = "starred"
		static let authors = "authors"

		// Author
		static let authorName = "name"
		static let authorURL = "url"
		static let authorAvatarURL = "avatarURL"
		static let authorEmailAddress = "emailAddress"

		// Internal
		static let accountID = "accountID"
	}

	func exportDictionary() -> [String: Any] {
		var d = [String: Any]()

		d[Key.articleID] = article.articleID
		d[Key.uniqueID] = article.uniqueID

		if let feed = article.webFeed {
			d[Key.feedURL] = feed.url
		}

		d[Key.webFeedID] = article.webFeedID
		d[Key.title] = article.title ?? nil
		d[Key.contentHTML] = article.contentHTML ?? nil
		d[Key.contentText] = article.contentText ?? nil
		d[Key.url] = article.rawLink ?? nil
		d[Key.externalURL] = article.rawExternalLink ?? nil
		d[Key.summary] = article.summary ?? nil
		d[Key.imageURL] = article.rawImageLink ?? nil
		d[Key.datePublished] = article.datePublished ?? nil
		d[Key.dateModified] = article.dateModified ?? nil
		d[Key.dateArrived] = article.status.dateArrived
		d[Key.authors] = authorDictionaries() ?? nil

		return d
	}

	func internalDictionary() -> [String: Any] {
		var d = exportDictionary()
		d[Key.accountID] = article.accountID
		return d
	}

	func authorDictionary(_ author: Author) -> [String: Any] {
		var d = [String: Any]()

		d[Key.authorName] = author.name ?? nil
		d[Key.authorURL] = author.url ?? nil
		d[Key.authorAvatarURL] = author.avatarURL ?? nil
		d[Key.authorEmailAddress] = author.emailAddress ?? nil

		return d
	}

	func authorDictionaries() -> [[String: Any]]? {
		guard let authors = article.authors, !authors.isEmpty else {
			return nil
		}
		return authors.map{ authorDictionary($0) }
	}
}

