//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
import MarkupEditor

class BasicTests: XCTestCase, MarkupDelegate {
    var selectionState: SelectionState = SelectionState()
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation = XCTestExpectation(description: "Loaded")
    var undoSetHandler: (()->Void)?
    var inputHandler: (()->Void)?
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        webView = MarkupWKWebView(markupDelegate: self)
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
        wait(for: [loadedExpectation], timeout: 10)
    }
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Since we marked self as the markupDelegate, we receive the markupDidLoad message
        loadedExpectation.fulfill()
        handler?()
    }
    
    /// Execute the inputHandler once if defined, then nil it out
    func markupInput(_ view: MarkupWKWebView) {
        guard let inputHandler = inputHandler else {
            return
        }
        //print("*** handling input")
        inputHandler()
        self.inputHandler = nil
    }
    
    /// Use the inputHandlers in order, removing them as we use them
    func markupUndoSet(_ view: MarkupWKWebView) {
        guard let undoSetHandler = undoSetHandler else {
            return
        }
        //print("*** handling undoSet")
        undoSetHandler()
        self.undoSetHandler = nil
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func assertEqualStrings(expected: String, saw: String?) {
        XCTAssert(expected == saw, "Expected \(expected), saw: \(saw ?? "nil")")
    }
    
    func addInputHandler(_ handler: @escaping (()->Void)) {
        inputHandler = handler
    }
    
    func addUndoSetHandler(_ handler: @escaping (()->Void)) {
        undoSetHandler = handler
    }
    
    func testLoad() throws {
        print("Test: Ensure loadInitialHtml has run.")
        // Do nothing other than run setupWithError
    }

    func testFormats() throws {
        // Select a range in a P styled string, apply a format to it
        for format in FormatContext.AllCases {
            var test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        test.description = "Set format to \(format.description)"
                        test.printDescription()
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUnformats() throws {
        // Given a range of formatted text, toggle the format off
        for format in FormatContext.AllCases {
            var test = HtmlTest.forUnformatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        test.description = "Unformat from \(format.description)"
                        test.printDescription()
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testFormatSelections() throws {
        // Select a caret location in a formatted string and make sure getSelection identifies the format properly
        // This is important for the toolbar indication of formatting as the cursor selection changes
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: format.tag)
            let startHtml = formattedString.styledHtml(adding: .P)
            let description = "Select inside of format \(format.tag)"
            print(" * Test: \(description)")
            let expectation = XCTestExpectation(description: description)
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: format.tag, startOffset: 1, endId: format.tag, endOffset: 1) { result in
                        XCTAssert(result)
                        switch format {
                        case .B:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.bold)
                                expectation.fulfill()
                            }
                        case .I:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.italic)
                                expectation.fulfill()
                            }
                        case .U:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.underline)
                                expectation.fulfill()
                            }
                        case .STRIKE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.strike)
                                expectation.fulfill()
                            }
                        case .SUB:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sub)
                                expectation.fulfill()
                            }
                        case .SUP:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sup)
                                expectation.fulfill()
                            }
                        case .CODE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.code)
                                expectation.fulfill()
                            }
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testMultiFormats() throws {
        // Inline comments show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Unselect outer formatting across elements with nested formatting",
                    startHtml: "<p><b><u id=\"u1\">Word 1</u><u> Word 2 </u><u id=\"u3\">Word 3</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">Wo</u></b><u>rd 1</u><u> Word 2 </u><u id=\"u3\">Wo</u><b><u>rd 3</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Unselect part of outer formatting within nested formatting",
                    startHtml: "<b>Hello <u id=\"u\">bold and underline</u> world</b>",
                    endHtml: "<b>Hello <u id=\"u\">bold </u></b><u>and</u><b><u> underline</u> world</b>",
                    startId: "u",
                    startOffset: 5,
                    endId: "u",
                    endOffset: 8
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat italic",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\">Hello world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"world\" is italic, select \"|Hello <i>world</i>|\" and format bold",
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><b>Hello </b><i id=\"i\"><b>world</b></i></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"Hello \" is italic and bold, \"wo|rld\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Span paragraphs from unformatted to nested formatted",
                    startHtml: "<p id=\"p1\">Hello <i id=\"i1\">world</i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><b>Hello </b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\">Hello <i id=\"i2\">wo<b>rld</b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<h1><b id=\"b\"><i id=\"i\">Hello </i>world</b></h1>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h2 with h6",
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h6>Hello world</h6>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h3 with p",
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<p>Hello world</p>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testMultiStyles() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1, selection in embedded format",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "i1",
                    startOffset: 2,
                    endId: "i3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format both ends",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "b1",
                    startOffset: 1,
                    endId: "b3",
                    endOffset: 1,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format at start",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "b1",
                    startOffset: 1,
                    endId: "i3",
                    endOffset: 2,
                    startChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format at end",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "i1",
                    startOffset: 2,
                    endId: "b3",
                    endOffset: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles across multiple paragraphs")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }

    func testBlockQuotes() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Increase quote level, selection in text element",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level, selection in a non-text element",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, no styling",
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, with styling",
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 2 to 1, selection in a non-text element",
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level in an embedded paragraph in a blockquote, selection in a non-text element",
                    startHtml: "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Make a paragraph into an unordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Change one of the list items in a multi-element unordered list to an ordered list item",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testListEnterCollapsed() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Enter at end of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5></li><li><h5><br></h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5><br></h5></li><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 0,
                    endId: "h5",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bul|leted item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>leted&nbsp;<i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "h5",
                    endOffset: 2,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 16,
                    endId: "ol1",
                    endOffset: 16
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 0,
                    endId: "ol1",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 6,
                    endId: "ol1",
                    endOffset: 6
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in empty list item at end of list.",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5 id=\"h52\"><br></h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li></ul><h5 id=\"h52\"><br></h5>",
                    startId: "h52",
                    startOffset: 0,
                    endId: "h52",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed in a list with various collapsed selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testListEnterRange() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Word in single styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "Numbered "
                    startOffset: 2,
                    endId: "ol1",
                    endOffset: 11,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Word in single unstyled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered&nbsp;</li><li><p>6.</p></li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "item "
                    startOffset: 9,
                    endId: "ol6",
                    endOffset: 14
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Part of a formatted item in a styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">i</i></h5></li><li><h5><i>m</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select "<i id=\"i\">i|te|m</i>" which is itself inside of an <h5>
                    startOffset: 1,
                    endId: "i",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "The entire formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">\u{200B}</i></h5></li><li><h5><i>\u{200B}</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select the entire "<i id=\"i\">item</i>" which is itself inside of an <h5>
                    startOffset: 0,
                    endId: "i",
                    endOffset: 4
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "P |Numbered item 1."
                    startOffset: 2,
                    endId: "ol3",       // Select "P |Numbered item 3."
                    endOffset: 2,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one unstyled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li><p><br></p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "|Numbered item 6."
                    startOffset: 0,
                    endId: "ol8",       // Select "|Numbered item 8."
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li><p><br></p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "|P Numbered item 2."
                    startOffset: 0,
                    endId: "ol4",       // Select "|P Numbered item 4."
                    endOffset: 0,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a styled list item, end in an unstyled one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Num</p></li><li><p>bered item 7.</p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "P Num|bered item 2."
                    startOffset: 5,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    startChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bul</h5></li><li><h5>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h51",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>\u{200B}</i>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",       // Select "<i id=\"i\">it!em</i>"
                    startOffset: 2,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>\u{200B}</i>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",       // Select "<i id=\"i\">it!em</i>"
                    startOffset: 2,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Enter being pressed in a list with various range selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testInsertEmpty() throws {
        /*
         From this oldie but goodie... https://bugs.webkit.org/show_bug.cgi?id=15256
         
         For example, given an HTML block like this:

             <div contentEditable="true"><div id="scratchpad"></div></div>

         and code like this:

             document.getElementById("scratchpad").innerHTML = "<div id=\"foo\">blah</div><div id=\"bar\">blah</div>";

             var sel = window.getSelection();
             sel.removeAllRanges();
             var range = document.createRange();

             range.setStartAfter(document.getElementById("foo"));
             range.setEndAfter(document.getElementById("foo"));
             sel.addRange(range);

             document.execCommand("insertHTML", false, "<div id=\"baz\">-</div>");

         One would expect this snippet to result in:

             <div id="foo">blah</div><div id="baz">-</div><div id="bar">blah</div>

         but instead, you get:

             <div id="foo">blah</div><div id="bar">-blah</div>

         I've tried every combination of set{Start|End}{After|Before|} that I can think of, and even things like setBaseAndExtent, modifying the selection object directly by extending it in either direction, etc.  Nothing works.
         Comment 38
         */
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            )
        ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting.
    ///
    /// Text that comes in via the pasteboard contains a "proper" HTML document, including meta tags and extensive
    /// styling to capture the state from the source document. The MarkupEditor strictly controls the styling and other
    /// content of the document it works on, so much of this content needs to be stripped from the incoming HTML
    /// before pasting. By testing the preprocessing itself, the tests for HTML paste (and the corresponding text paste)
    /// can be done using "clean" strings.
    func testPasteHtmlPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                endHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 id=\"h1\" style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<h1 id=\"h1\">Welcome to the MarkupEditor Demo</h1><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p><b>List of One Liners</b></p><p>Let\'s solve this problem for this array:</p><p><code>var array = [\'A\', \'B\', \'C\'];\n</code></p><p><b>1. Remove only the first:</b>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.indexOf(\'B\'), 1);\n</code></p><p><b>2. Remove only the last:</b>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.lastIndexOf(\'B\'), 1);\n</code></p><p><b>3. Remove all occurrences:</b></p><p><code>array = array.filter(v =&gt; v !== \'B\'); </code></p>",
                startId: "p", 
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Cleaning up html we get from the paste buffer")
            self.webView.testPasteHtmlPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3)
        }
    }
    
    func testPasteHtml() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello <b>bold</b> worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <b>bold</b> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello <i>bold</i> worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <i>bold</i> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello <b>bold</b> world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">ju</b></p><p>Hello <i>bold</i> world</p><p><b>st</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <i>bold</i> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello <b>bold</b> world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello world</p><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello <b>bold</b> world</p><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello world</p><p><br></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello <b>bold</b> world</p><p><br></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello <b>bold</b> world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><h5>Hello world</h5>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><h5>Hello <b>bold</b> world</h5>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <b>bold</b> world</h5>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteHtml(test.pasteString) {
                            self.webView.getHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 3)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting text (aka "Paste and Match Style").
    ///
    /// See comments in the `testPasteHtmlPreprocessing` method.
    ///
    /// The "pasteText" function (via the "Paste and Match Style" edit menu) pastes the MarkupEditor
    /// equivalent of plain text. To do that, it uses <p> for all styling and removes all formatting (e.g., <b>, <i>, etc).
    /// The text preprocessing does the same preprocessing as the HTML preprocessing, plus this additional
    /// style and format removal, along with link removal.
    func testPasteTextPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                endHtml: "<p>This is just a simple paragraph.</p>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 id=\"h1\" style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<p>Welcome to the MarkupEditor Demo</p><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p>List of One Liners</p><p>Let\'s solve this problem for this array:</p><p>var array = [\'A\', \'B\', \'C\'];\n</p><p>1. Remove only the first:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.indexOf(\'B\'), 1);\n</p><p>2. Remove only the last:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.lastIndexOf(\'B\'), 1);\n</p><p>3. Remove all occurrences:</p><p>array = array.filter(v =&gt; v !== \'B\'); </p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up some text from Xcode",
                startHtml: "const _pasteHTML = function(html, oldUndoerData, undoable=true) {\n    const redoing = !undoable && (oldUndoerData !== null);\n    let sel = document.getSelection();\n    let anchorNode = (sel) ? sel.anchorNode : null;\n    if (!anchorNode) {\n        MUError.NoSelection.callback();\n        return null;\n    };",
                endHtml: "const _pasteHTML = function(html, oldUndoerData, undoable=true) {<br>&nbsp;&nbsp;&nbsp;&nbsp;const redoing = !undoable &amp;&amp; (oldUndoerData !== null);<br>&nbsp;&nbsp;&nbsp;&nbsp;let sel = document.getSelection();<br>&nbsp;&nbsp;&nbsp;&nbsp;let anchorNode = (sel) ? sel.anchorNode : null;<br>&nbsp;&nbsp;&nbsp;&nbsp;if (!anchorNode) {<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MUError.NoSelection.callback();<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return null;<br>&nbsp;&nbsp;&nbsp;&nbsp;};",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Get \"unformatted text\" from the paste buffer")
            self.webView.testPasteTextPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3)
        }
    }
    
    func testPasteText() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello bold worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <b>bold</b> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello bold worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <i>bold</i> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello bold world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">ju</b></p><p>Hello bold world</p><p><b>st</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <i>bold</i> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello bold world</p><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello world</p><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello bold world</p><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello world</p><p><br></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello bold world</p><p><br></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <b>bold</b> world</h5>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteText(test.pasteString) {
                            self.webView.getHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 3)
        }
    }
    
    func testPasteImage() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Image in P - Paste image at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteImage(UIImage(systemName: "calendar")) {
                            self.webView.getHtml() { pasted in
                                // This is pretty brittle, but the image file name is a generated UUID. The test just makes
                                // sure that the <img> element is where we expect in this simple case and the file actually
                                // exists.
                                if let pasted = pasted {
                                    XCTAssertTrue(pasted.contains("<img src=\""))
                                    XCTAssertTrue(pasted.contains("\" tabindex=\"-1\">"))
                                    let imageFileRange = pasted.index(pasted.startIndex, offsetBy: 30)..<pasted.index(pasted.endIndex, offsetBy: -42)
                                    let imageFileName = String(pasted[imageFileRange])
                                    XCTAssertTrue(self.webView.resourceExists(imageFileName))
                                    expectation.fulfill()
                                } else {
                                    XCTFail("The pasted HTML was not returned properly.")
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 3)
        }
    }

}
