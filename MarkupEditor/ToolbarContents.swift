//
//  ToolbarContents.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/3/22.
//

import Foundation

/// ToolbarContents controls the contents of the MarkupToolbar and the MarkupMenu.
///
/// The ToolbarContents contains a set of Bools that are used in the various toolbars to determine
/// whether contents are shown. The top-level `correction`, `insert`,  `style`, and `format`
/// entries indicate whether those toolbars are included at all in the MarkupToolbar. The other `*contents`
/// entries point to similar structs for the individual toolbar contents.
///
/// Set `custom` to use your own instance of ToolbarContents to customize the contents of your
/// MarkupToolbar and MarkupMenu. Internally, the toolbars and menus access `shared`, which
/// will be your `custom` ToolbarContents or the default ToolbarContents instance if you did not
/// specify `custom`.
public struct ToolbarContents {
    public static var custom: ToolbarContents?
    public static let shared = custom ?? ToolbarContents()
    
    public var correction: Bool
    public var insert: Bool
    public var style: Bool
    public var format: Bool
    
    public var insertContents: InsertContents
    public var styleContents: StyleContents
    public var formatContents: FormatContents
    public var tableContents: TableContents
    
    public init(
        correction: Bool = true,
        insert: Bool = true,
        style: Bool = true,
        format: Bool = true,
        insertContents: InsertContents = InsertContents(),
        styleContents: StyleContents = StyleContents(),
        formatContents: FormatContents = FormatContents(),
        tableContents: TableContents = TableContents()
    ) {
        self.correction = correction
        self.insert = insert
        self.style = style
        self.format = format
        self.insertContents = insertContents
        self.styleContents = styleContents
        self.formatContents = formatContents
        self.tableContents = tableContents
    }
}

/// Identify which of the InsertToolbar items will show up
public struct InsertContents {
    public var link: Bool
    public var image: Bool
    public var table: Bool
    
    public init(link: Bool = true, image: Bool = true, table: Bool = true) {
        self.link = link
        self.image = image
        self.table = table
    }
}

/// Identify whether the list and indent/outdent items will show up
public struct StyleContents {
    public var list: Bool
    public var dent: Bool
    
    public init(list: Bool = true, dent: Bool = true) {
        self.list = list
        self.dent = dent
    }
}

/// Identify whether the code, strikethrough, and sub/superscript items will show up
public struct FormatContents {
    public var code: Bool
    public var strike: Bool
    public var subSuper: Bool
    
    public init(code: Bool = true, strike: Bool = true, subSuper: Bool = true) {
        self.code = code
        self.strike = strike
        self.subSuper = subSuper
    }
}

/// Identify whether to allow table borders to be specified
public struct TableContents {
    public var border: Bool
    
    public init(border: Bool = true) {
        self.border = border
    }
}
