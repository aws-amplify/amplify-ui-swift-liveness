//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit

final class FreshnessView: UIView {
    let oldRectangle = UIView()
    let fractionalRectangle = UIView()

    var fractionalRectangleBottom: NSLayoutConstraint?
    var oldRectangleTop: NSLayoutConstraint?

    func clearColors() {
        backgroundColor = .clear
        oldRectangle.backgroundColor = .clear
        fractionalRectangle.backgroundColor = .clear
    }

    init() {
        super.init(frame: .zero)
        oldRectangle.translatesAutoresizingMaskIntoConstraints = false
        fractionalRectangle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(oldRectangle)
        addSubview(fractionalRectangle)

        fractionalRectangleBottom = fractionalRectangle.bottomAnchor.constraint(equalTo: topAnchor)
        oldRectangleTop = oldRectangle.topAnchor.constraint(equalTo: topAnchor)

        fractionalRectangleBottom?.isActive = true
        oldRectangleTop?.isActive = true

        NSLayoutConstraint.activate([
            oldRectangle.leadingAnchor.constraint(equalTo: leadingAnchor),
            oldRectangle.bottomAnchor.constraint(equalTo: bottomAnchor),
            oldRectangle.trailingAnchor.constraint(equalTo: trailingAnchor),

            fractionalRectangle.topAnchor.constraint(equalTo: topAnchor),
            fractionalRectangle.leadingAnchor.constraint(equalTo: leadingAnchor),
            fractionalRectangle.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

