import SwiftUI
import ChessCoachShared
import ChessCoachEngine

// MARK: - ChessBoardView

public struct ChessBoardView: View {
    @Binding var position: Position
    let interactive: Bool
    let engineLines: [EngineLine]
    let onMove: ((Move) -> Void)?
    /// Restricts interaction to this color only. Nil means any legal piece can be moved
    /// (normal play mode). In puzzle mode this should match the FEN side-to-move.
    let playerColor: PieceColor?

    private let theme = ChessTheme.midnightStudy
    @State private var selectedSquare: Square?
    @State private var legalDestinations: [Square] = []
    @State private var draggedPiece: (square: Square, piece: Piece)?
    @State private var dragOffset: CGSize = .zero

    public init(
        position: Binding<Position>,
        interactive: Bool = true,
        engineLines: [EngineLine] = [],
        onMove: ((Move) -> Void)? = nil,
        playerColor: PieceColor? = nil
    ) {
        self._position = position
        self.interactive = interactive
        self.engineLines = engineLines
        self.onMove = onMove
        self.playerColor = playerColor
    }

    public var body: some View {
        GeometryReader { geometry in
            boardBody(geometry: geometry)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Extracted to help Swift compiler with type inference
    @ViewBuilder
    private func boardBody(geometry: GeometryProxy) -> some View {
        let size = min(geometry.size.width, geometry.size.height)
        let squareSize = size / 8

        ZStack {
            squaresLayer(size: size, squareSize: squareSize)
            arrowsOverlay(squareSize: squareSize)
            draggedPieceOverlay(squareSize: squareSize, boardSize: size)
        }
        .frame(width: size, height: size, alignment: .center)
        .gesture(interactive ? makeDragGesture(squareSize: squareSize) : nil)
    }

    @ViewBuilder
    private func squaresLayer(size: CGFloat, squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach((0..<8).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { file in
                        squareCell(file: file, rank: rank, squareSize: squareSize)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func squareCell(file: Int, rank: Int, squareSize: CGFloat) -> some View {
        let sq = Square(file: file, rank: rank)
        let isLight = (file + rank) % 2 == 0
        let isSelected = selectedSquare == sq
        let isLegalDest = legalDestinations.contains(sq)
        let isLastMoveCell = isLastMoveSquare(sq)
        let isCheckCell = isCheckSquare(sq)
        let piece = position.piece(at: sq)
        let isDragTgt = isLegalDest && draggedPiece != nil

        SquareView(
            square: sq,
            size: squareSize,
            theme: theme,
            isLight: isLight,
            isSelected: isSelected,
            isLegalDestination: isLegalDest,
            isLastMove: isLastMoveCell,
            isCheck: isCheckCell,
            piece: piece,
            isDragTarget: isDragTgt,
            onTap: interactive ? { handleTap(sq) } : nil
        )
    }

    @ViewBuilder
    private func arrowsOverlay(squareSize: CGFloat) -> some View {
        if !engineLines.isEmpty {
            EngineArrowsOverlay(lines: engineLines, squareSize: squareSize)
        }
    }

    @ViewBuilder
    private func draggedPieceOverlay(squareSize: CGFloat, boardSize: CGFloat) -> some View {
        if let dragged = draggedPiece {
            PieceView(piece: dragged.piece, size: squareSize)
                .offset(dragOffset)
                .position(x: boardSize / 2, y: boardSize / 2)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Helpers

    private func isLastMoveSquare(_ square: Square) -> Bool {
        false
    }

    private func isCheckSquare(_ square: Square) -> Bool {
        guard position.isCheck else { return false }
        return position.piece(at: square)?.kind == .king
    }

    private func handleTap(_ square: Square) {
        if let selected = selectedSquare {
            let moves = position.legalMoves(from: selected)
            if let move = moves.first(where: { $0.to == square }) {
                selectedSquare = nil
                legalDestinations = []
                var newPos = position
                _ = newPos.makeMove(move)
                position = newPos
                onMove?(move)
            } else if position.piece(at: square) != nil {
                if playerColor == nil || position.piece(at: square)?.color == playerColor {
                    selectedSquare = square
                    legalDestinations = moves.map { $0.to }
                }
            } else {
                selectedSquare = nil
                legalDestinations = []
            }
        } else {
            if position.piece(at: square) != nil {
                if playerColor == nil || position.piece(at: square)?.color == playerColor {
                    selectedSquare = square
                    legalDestinations = position.legalMoves(from: square).map { $0.to }
                }
            }
        }
    }

    private func makeDragGesture(squareSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draggedPiece == nil {
                    let file = Int(value.location.x / squareSize)
                    let rank = 7 - Int(value.location.y / squareSize)
                    let clampedFile = max(0, min(7, file))
                    let clampedRank = max(0, min(7, rank))
                    let sq = Square(file: clampedFile, rank: clampedRank)
                    guard let piece = position.piece(at: sq),
                          piece.color == position.turn,
                          playerColor == nil || piece.color == playerColor else { return }
                    selectedSquare = sq
                    draggedPiece = (sq, piece)
                    legalDestinations = position.legalMoves(from: sq).map { $0.to }
                    dragOffset = .zero
                }
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height)
            }
            .onEnded { value in
                guard let dragged = draggedPiece else { return }
                let file = Int(value.location.x / squareSize)
                let rank = 7 - Int(value.location.y / squareSize)
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
    let size: CGFloat
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
            if isLegalDestination && piece == nil {
                Circle()
                    .fill(theme.primary.opacity(0.5))
                    .frame(width: size * 0.25, height: size * 0.25)
            }
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
    let size: CGFloat

    var body: some View {
        Text(piece.character)
            .font(.system(size: size * 0.8, weight: .bold))
            .foregroundColor(piece.color == .white ? .white : .black)
            .shadow(color: piece.color == .white ? .black.opacity(0.5) : .white.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

// MARK: - EngineArrowsOverlay

struct EngineArrowsOverlay: View {
    let lines: [EngineLine]
    let squareSize: CGFloat

    var body: some View {
        Canvas { context, _ in
            for (index, line) in lines.prefix(3).enumerated() {
                guard line.moves.count >= 2 else { continue }
                let fromCG = squareCG(fromUCi: line.moves[0])
                let toCG = squareCG(fromUCi: line.moves[1])
                drawArrow(context: context, from: fromCG, to: toCG, color: arrowColor(index: index))
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
        let headLen = min(30.0, length * 0.3)

        let endX = to.x - cos(angle) * headLen * 0.5
        let endY = to.y - sin(angle) * headLen * 0.5
        path.addLine(to: CGPoint(x: endX, y: endY))

        let leftX = endX - cos(angle - .pi / 6) * headLen
        let leftY = endY - sin(angle - .pi / 6) * headLen
        let rightX = endX - cos(angle + .pi / 6) * headLen
        let rightY = endY - sin(angle + .pi / 6) * headLen

        path.move(to: CGPoint(x: endX, y: endY))
        path.addLine(to: CGPoint(x: leftX, y: leftY))
        path.move(to: CGPoint(x: endX, y: endY))
        path.addLine(to: CGPoint(x: rightX, y: rightY))

        context.stroke(path, with: .color(color), lineWidth: 3)
    }

    private func squareCG(fromUCi uci: String) -> CGPoint {
        guard uci.count >= 4,
              let sq = Square(description: String(uci.prefix(2))) else {
            return .zero
        }
        let x = CGFloat(7 - sq.file) * squareSize + squareSize / 2
        let y = CGFloat(sq.rank) * squareSize + squareSize / 2
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
