//
//  CarretView.swift
//  CodeEditViewSample
//
//  Created by Marcin Krzyzanowski on 25/08/2020.
//

import Cocoa

public enum CarretStyle {
    case line
}

final class CarretView: NSView {
    var style: CarretStyle = .line

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        switch style {
            case .line:
                drawLineStyle(in: context, dirtyRect: dirtyRect)
        }
    }

    private func drawLineStyle(in context: CGContext, dirtyRect: NSRect) {
        context.setFillColor(NSColor.textColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 2, height: bounds.height))
    }
}
