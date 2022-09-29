//
//  CodeView.swift
//  HostApp
//
//  Created by Saultz, Ian on 7/8/22.
//

import Foundation
import SwiftUI

import Primitives

struct CodeView: View {
    
    struct Modifier {
        let name: String
        let value: String
        var includeDot = true
    }
    
    let attributedString: AttributedString
    
    init(attributedString: AttributedString) {
        self.attributedString = attributedString
    }
    
    init(component: String, modifiers: [Modifier]) {
        attributedString = .namespace + .dot + .component(component) + .parens + .newline +
            modifiers.reduce(into: AttributedString()) {
                if $1.includeDot {
                    $0 += .tab + .modifier($1.name, with: $1.value) + .newline
                } else {
                    $0 += .tab + .modifier($1.name) + .leftParen + .modifier($1.value) + .rightParen + .newline
                }
                
            }
    }
    
    var body: some View {
        Text(attributedString)
            .padding()
            .background(
                Color(UIColor.tertiarySystemBackground)
                    .cornerRadius(8)
            )
        
    }
}


extension AttributedString {
    static let dot: AttributedString = {
        AttributedString(".", attributes: .init([.foregroundColor: UIColor.label]))
    }()
    
    static let namespace: AttributedString = {
        AttributedString("AmplifyUI", attributes: .init([.foregroundColor: UIColor.systemTeal]))
    }()
    
    static let leftParen: AttributedString = {
        AttributedString("(", attributes: .init([.foregroundColor: UIColor.label]))
    }()
    
    static let rightParen: AttributedString = {
        AttributedString(")", attributes: .init([.foregroundColor: UIColor.label]))
    }()
    
    static var parens: AttributedString { .leftParen + .rightParen }
    
    static func component(_ name: String) -> AttributedString {
        AttributedString(name, attributes: .init([.foregroundColor: UIColor.systemPurple]))
    }
    
    static func modifier(_ name: String) -> AttributedString {
        AttributedString(name, attributes: .init([.foregroundColor: UIColor.systemGreen]))
    }
    
    static func modifier(_ name: String, with value: String) -> AttributedString {
        .dot + modifier(name) + .leftParen + .dot + .modifier(value) + .rightParen
    }
    
    static let newline = AttributedString("\n")
    static let tab = AttributedString("\t")
    
    static func label(_ text: String) -> AttributedString {
        AttributedString(text, attributes: .init([.foregroundColor: UIColor.label]))
    }
}
