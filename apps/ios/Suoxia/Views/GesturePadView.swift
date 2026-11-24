import SwiftUI

struct GesturePadView: View {
    let onComplete: (String) -> Void
    @State private var selected: [Int] = []
    @State private var dragPoint: CGPoint? = nil

    private let size: CGFloat = 220

    private var centers: [CGPoint] {
        let step = size / 3
        return (0..<9).map { idx in
            let r = CGFloat(idx / 3)
            let c = CGFloat(idx % 3)
            return CGPoint(x: c * step + step / 2, y: r * step + step / 2)
        }
    }

    var body: some View {
        ZStack {
            Path { path in
                for (i, idx) in selected.enumerated() {
                    let pt = centers[idx]
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                if !selected.isEmpty, let drag = dragPoint {
                    path.addLine(to: drag)
                }
            }
            .stroke(Color.indigo, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            ForEach(0..<9, id: \.self) { idx in
                let active = selected.contains(idx)
                ZStack {
                    if active {
                        Circle()
                            .fill(Color.indigo.opacity(0.15))
                            .overlay(Circle().stroke(Color.indigo.opacity(0.5), lineWidth: 2))
                            .frame(width: 44, height: 44)
                    }
                    Circle()
                        .fill(active ? Color.indigo : Color.gray.opacity(0.45))
                        .frame(width: active ? 14 : 12, height: active ? 14 : 12)
                }
                .position(centers[idx])
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragPoint = value.location
                    for (idx, pt) in centers.enumerated() where !selected.contains(idx) {
                        if hypot(value.location.x - pt.x, value.location.y - pt.y) <= 26 {
                            selected.append(idx)
                        }
                    }
                }
                .onEnded { _ in
                    let pat = selected.map(String.init).joined()
                    selected = []
                    dragPoint = nil
                    if !pat.isEmpty { onComplete(pat) }
                }
        )
    }
}
