import SwiftUI

// MARK: - ChessBoardView

public struct ChessBoardView: View {
    @Binding var position: Position
    let interactive: Bool
    let engineLines: [EngineLine]
    let onMove: ((Move) -> Void)?

    private let theme = ChessTheme.midnightStudy
    @State private var selectedSquare: Square?
    @State private var legalDestinations: [Square] = []
    @State private var draggedPiece: (square: Square, piece: Piece)?
    @State private var dragOffset: CGSize = .zero

    public init(
        position: Binding<Position>,
        interactive: Bool = true,
        engineLines: [EngineLine] = [],
        onMove: ((Move) -> Void)? = nil
    ) {
        self._position = position
        self.interactive = interactive
        self.engineLines = engineLines
        self.onMove = onMove
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let squareSize = size / 8

            ZStack {
                // Board squares
                VStack(spacing: 0) {
                    ForEach((0..<8).reversed(), id: \.self) { rank in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { file in
                                let square = Square(file: file, rank: rank)
                                SquareView(
                                    square: square,
                                    size: squareSize,
                                    theme: theme,
                                    isLight: (file + rank) % 2 == 0,
                                    isSelected: selectedSquare == square,
                                    isLegalDestination: legalDestinations.contains(square),
                                    isLastMove: isLastMoveSquare(square),
                                    isCheck: isCheckSquare(square),
                                    piece: position.piece(at: square),
                                    isDragTarget: draggedPiece?.square == square && draggedPiece?.square != square,
                                    onTap: interactive ? { handleTap(square) } : nil
                                )
                            }
                        }
                    }
                }

                // Engine arrows overlay
                if !engineLines.isEmpty {
                    EngineArrowsOverlay(lines: engineLines, squareSize: squareSize)
                }

                // Dragged piece overlay
                if let dragged = draggedPiece {
                    PieceView(
                        piece: dragged.piece,
                        size: squareSize
                    )
                    .offset(dragOffset)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(width: size, height: size, alignment: .center)
            .gesture(
                interactive ? dragGesture(squareSize: squareSize) : nil
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Helpers

    private func isLastMoveSquare(_ square: Square) -> Bool {
        false // Set by lastMove tracking if needed
    }

    private func isCheckSquare(_ square: Square) -> Bool {
        guard position.isCheck else { return false }
        return position.piece(at: square)?.kind == .king
    }

    private func handleTap(_ square: Square) {
        if let selected = selectedSquare {
            // Try to move
            let moves = position.legalMoves(from: selected)
            if let move = moves.first(where: { $0.to == square }) {
                selectedSquare = nil
                legalDestinations = []
                var newPos = position
                _ = newPos.makeMove(move)
                position = newPos
                onMove?(move)
            } else if position.piece(at: square) != nil {
                selectedSquare = square
                legalDestinations = moves.map { $0.to }
            } else {
                selectedSquare = nil
                legalDestinations = []
            }
        } else {
            if position.piece(at: square) != nil {
                selectedSquare = square
                legalDestinations = position.legalMoves(from: square).map { $0.to }
            }
        }
    }

    private func dragGesture(squareSize: CGF) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draggedPiece == nil {
                    let file = Int(value.location.x / squareSize)
                    let rank = 7 - Int(value.location.y / squareSize)
                    guard let square = Optional(Square(file: max(0, min(7, file)), rank: max(0, min(7, rank)))),
                          let piece = position.piece(at: square),
                          piece.color == position.turn else { return }
                    selectedSquare = square
                    draggedPiece = (square, piece)
                    legalDestinations = position.legalMoves(from: square).map { $0.to }
                    dragOffset = .zero
                }
                dragOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )
            }
            .onEnded { value in
                guard let dragged = draggedPiece else { return }
                let file = Int((value.location.x) / squareSize)
                let rank = 7 - Int((value.location.y) / squareSize)
                let target = Square(file: max(0, min(7, file)), rank: max(0, min(7, rank)))

                if legalDestinations.contains(target) {
                    let moves = position.legalMoves(from: dragged.square)
                    if let move = moves.first(where: { $0.to == target }) {
                        var newPos = position
                        _ = newPos.makeMove(move)
                        position = newPos
                        onMove?(move)
                    }
                }

                draggedPiece = nil
                selectedSquare = nil
                legalDestinations = []
                dragOffset = .zero
            }
    }
}

// MARK: - SquareView

struct SquareView: View {
    let square: Square
    let size: CGF
    let theme: ChessTheme
    let isLight: Bool
    let isSelected: Bool
    let isLegalDestination: Bool
    let isLastMove: Bool
    let isCheck: Bool
    let piece: Piece?
    let isDragTarget: Bool
    let onTap: (() -> Void)?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(squareColor)

            if piece != nil {
                PieceView(piece: piece!, size: size * 0.9)
                    .position(x: size / 2, y: size / 2)
            }

            // Legal move dot
            if isLegalDestination && piece == nil {
                Circle()
                    .fill(theme.primary.opacity(0.5))
                    .frame(width: size * 0.25, height: size * 0.25)
            }

            // Capture highlight
            if isLegalDestination && piece != nil {
                Circle()
                    .stroke(theme.primary, lineWidth: 3)
                    .frame(width: size * 0.9, height: size * 0.9)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture { onTap?() }
    }

    private var squareColor: Color {
        if isCheck { return theme.accent.opacity(0.7) }
        if isSelected { return theme.primary.opacity(0.5) }
        if isLegalDestination { return theme.primary.opacity(0.25) }
        if isLastMove { return theme.primary.opacity(0.15) }
        return isLight ? theme.whiteSquare : theme.blackSquare
    }
}

// MARK: - PieceView

struct PieceView: View {
    let piece: Piece
    let size: CGF

    var body: some View {
        Text(piece.character)
            .font(.system(size: size * 0.8, weight: .bold))
            .foregroundColor(piece.color == .white ? .white : .black)
            .shadow(color: piece.color == .white ? .black.opacity(0.5) : .white.opacity(0.3),
                    radius: 1, x: 1, y: 1)
    }
}

// MARK: - EngineArrowsOverlay

struct EngineArrowsOverlay: View {
    let lines: [EngineLine]
    let squareSize: CGF

    var body: some View {
        Canvas { context, canvasSize in
            for (index, line) in lines.prefix(3).enumerated() {
                guard line.moves.count >= 2 else { continue }
                let from = square(fromUCi: line.moves[0])
                let to = square(fromUCi: line.moves[1])
                drawArrow(
                    context: context,
                    from: from,
                    to: to,
                    color: arrowColor(index: index)
                )
            }
        }
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let angle = atan2(dy, dx)
        let length = sqrt(dx*dx + dy*dy)
        let headLength = min(30.0, length * 0.3)
        let headWidth = headLength * 0.5

        let endX = to.x - cos(angle) * headLength * 0.5
        let endY = to.y - sin(angle) * headLength * 0.5
        path.addLine(to: CGPoint(x: endX, y: endY))

        let leftX = endX - cos(angle - .pi / 6) * headLength
        let leftY = endY - sin(angle - .pi / 6) * headLength
        let rightX = endX - cos(angle + .pi / 6) * headLength
        let rightY = endY - sin(angle + .pi / 6) * headLength

        path.move(to: CGPoint(x: endX, y: endY))
        path.addLine(to: CGPoint(x: leftX, y: leftY))
        path.move(to: CGPoint(x: endX, y: endY))
        path.addLine(to: CGPoint(x: rightX, y: rightY))

        context.stroke(path, with: .color(color), lineWidth: 3)
    }

    private func square(fromUCi uci: String) -> CGPoint {
        guard uci.count >= 4 else { return .zero }
        let fromSq = String(uci.prefix(2))
        guard let square = Square(description: fromSq) else { return .zero }
        let x = (7 - square.file) * squareSize + squareSize / 2
        let y = square.rank * squareSize + squareSize / 2
        return CGPoint(x: x, y: y)
    }

    private func arrowColor(index: Int) -> Color {
        switch index {
        case 0: return .green
        case 1: return .orange
        default: return .yellow
        }
    }
}
