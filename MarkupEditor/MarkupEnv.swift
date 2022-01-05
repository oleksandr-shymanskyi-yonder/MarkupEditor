//
//  MarkupEnv.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/20/21.
//

import Foundation
import UniformTypeIdentifiers

/// The available environmentObjects for the MarkupEditor.
///
/// Note that the MarkupEnv does not publish changes itself. Only the ObservableObjects it holds onto publish their changes.
public class MarkupEnv: ObservableObject {
    
    public let observedWebView = ObservedWebView()
    public let selectionState = SelectionState()
    public let toolbarPreference: ToolbarPreference
    public var toolbarPreferenceStyle: ToolbarPreference.Style { toolbarPreference.style }
    public let selectImage = SelectImage()
    public let supportedImageTypes: [UTType] = [.image, .movie]
    
    public init(style: ToolbarPreference.Style = .compact) {
        toolbarPreference = ToolbarPreference(style: style)
    }
}

public class ObservedWebView: ObservableObject, Identifiable {
    @Published public var selectedWebView: MarkupWKWebView?
    public var id: UUID = UUID()
    
    public init(_ webView: MarkupWKWebView? = nil) {
        selectedWebView = webView
    }
}

public class SelectImage: ObservableObject {
    @Published public var value: Bool
    
    public init(_ value: Bool = false) {
        self.value = value
    }
}
