//
//  RoundedCorner.swift
//  NexusVPN
//
//  简单的多角可选圆角 Shape，用于绘制套餐卡片左上角折角标签。
//

import SwiftUI

struct RoundedCorner: Shape {
    var corners: UIRectCorner = .allCorners
    var radius: CGFloat = .infinity

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

